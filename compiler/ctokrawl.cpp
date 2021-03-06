#include "krawl.hpp"
#include <sys/stat.h>
#include <llvm/ADT/SmallVector.h>
#include <llvm/ADT/StringRef.h>
#include <llvm/Support/FileSystem.h>
#include <llvm/Support/Path.h>
#include <llvm/Support/Host.h>
#include "cityhash/city.h"

struct module_cache_entry_t {
	std::string filename;
	uint64_t mtime;
};

struct module_cache_t {
	std::string header;
	std::vector<module_cache_entry_t> entries;
};

static std::string get_xdg_cache_dir()
{
	char *xdg_cache_home = getenv("XDG_CACHE_HOME");
	if (xdg_cache_home)
		return xdg_cache_home;

	char *home = getenv("HOME");
	if (!home)
		DIE("Missing HOME environment variable :-\\");

	std::string default_dir = home;
	default_dir += "/.cache";
	return default_dir;
}

static std::string cityhash64str(const char *data)
{
	char buf[12] = {0};
	uint64_t hash = CityHash64(data, strlen(data));
	base62_encode64(hash, buf);
	return buf;
}

static uint64_t mtime(const char *file)
{
	struct stat st;
	if (-1 == stat(file, &st))
		return 0;

	return st.st_mtime;
}

static bool is_valid_cache(const char *file, const char *header)
{
	FILE *f = fopen(file, "rb");
	if (!f)
		return false;

	FILE_reader_t fr(f);

	// oops, hash collision
	if (fr.read_string() != header) {
		fclose(f);
		return false;
	}

	size_t entries_n = fr.read_varuint();
	for (size_t i = 0, n = entries_n; i < n; ++i) {
		std::string &filename = fr.read_string();
		uint64_t now = mtime(filename.c_str());
		if (now != fr.read_uint64()) {
			fclose(f);
			return false;
		}
	}
	fclose(f);
	return true;
}

static std::string dump_to_tempfile(const char *data)
{
	int fd;
	llvm::SmallVector<char, 128> tmpfilename;
	llvm::sys::fs::unique_file("header-%%%%%%.h", fd, tmpfilename);
	tmpfilename.push_back(0);

	FILE *tmp = fdopen(fd, "w");
	if (!tmp)
		DIE("failed to open file descriptor returned by unique_file: %s",
		    &tmpfilename[0]);

	fprintf(tmp, "%s", data);
	fclose(tmp);

	return std::string(&tmpfilename[0]);
}

static void exec_and_capture_stdout(const char *cmd, std::vector<char> *out)
{
	FILE *cc = popen(cmd, "r");
	if (!cc)
		DIE("failed to execute a command: %s", cmd);

	if (!read_FILE(out, cc))
		DIE("failed to read command's output: %s", cmd);

	int ok = pclose(cc);
	if (ok != 0)
		DIE("clang exited with non-zero status: %d", ok);
}

static void prepare_module_cache(module_cache_t *mc, const char *header,
				 llvm::SmallVector<llvm::StringRef, 20> &deps)
{
	mc->header = header;
	for (size_t i = 0, n = deps.size(); i < n; ++i) {
		if (deps[i].empty())
			continue;
		std::string dep = deps[i].str();
		module_cache_entry_t entry = {dep, mtime(dep.c_str())};
		mc->entries.push_back(entry);
	}
}

static void generate_lib(const char *filename,
			 std::vector<sdecl_t*> *pkgdecls,
			 const char *prefix, const char *package)
{
	FILE *f = fopen(filename, "wb");
	if (!f) {
		fprintf(stderr, "Failed opening file for writing: %s\n", filename);
		exit(1);
	}
	{
		FILE_writer_t cout(f);
		brawl_serializer_t s;
		s.serialize(&cout, pkgdecls, prefix, package);
	}
	fclose(f);
}

static void write_cache(module_cache_t *mc, const char *cachefile)
{
	FILE *f = fopen(cachefile, "wb");
	if (!f)
		DIE("failed to open cache file for writing: %s", cachefile);

	FILE_writer_t fw(f);

	fw.write_string(mc->header);
	fw.write_varuint(mc->entries.size());
	for (size_t i = 0, n = mc->entries.size(); i < n; ++i) {
		fw.write_string(mc->entries[i].filename);
		fw.write_uint64(mc->entries[i].mtime);
	}

	fclose(f);
}

struct mini_all_t {
	sdecl_tracker_t dtracker;
	stype_tracker_t ttracker;
	scope_block_tracker_t stracker;

	source_group_t srcinfo;
	scope_block_t globalscope;
	scope_block_t pkgscope;
	std::vector<sdecl_t*> pkgdecls;
	diagnostic_t diag;
	node_t *ast;

	import_context_t ictx;

	mini_all_t(): ast(0)
	{
		fill_global_scope(&globalscope, &dtracker, &ttracker);
		pkgscope.parent = &globalscope;
		ictx.ttracker = &ttracker;
		ictx.dtracker = &dtracker;
	}

	~mini_all_t()
	{
		free_tracked_stypes(&ttracker);
		free_tracked_sdecls(&dtracker);
		free_tracked_scope_blocks(&stracker);
		delete ast;
	}
};

std::string update_c_module_hash(const char *header, const char *clang_path,
				 const char *clang_plugin_path)
{
	// compute paths
	std::string cachedir = get_xdg_cache_dir() + "/krawl";
	std::string cachefile = cachedir + "/" + cityhash64str(header);
	std::string brlfile = cachefile + ".brl";

	// if the cache is valid, we're done here
	if (is_valid_cache(cachefile.c_str(), header))
		return brlfile;

	// dump an includer file to a temporary file
	std::string includer;
	cppsprintf(&includer, "#include \"%s\"\n", header);

	std::string headerfile = dump_to_tempfile(includer.c_str());

	std::string plugin_ext;
	std::string hostTripple = llvm::sys::getHostTriple();
	if (hostTripple.find("linux") != std::string::npos) {
		plugin_ext = "so";
	} else if (hostTripple.find("darwin") != std::string::npos) {
		plugin_ext = "dylib";
	} else {
		DIE("FUUU");
	}

	// execute clang plugin and grab its output
	std::string p_clang = "clang";
	if (clang_path)
		p_clang = clang_path;
	std::string p_clang_plugin;
	cppsprintf(&p_clang_plugin,
		   KRAWL_INSTALL_PREFIX "/lib/krawl/libctokrawl.%s",
		   plugin_ext.c_str());
	if (clang_plugin_path)
		p_clang_plugin = clang_plugin_path;

	std::string cmd;
	cppsprintf(&cmd, "%s -cc1 -load %s -plugin c-to-krawl -x c %s",
		   p_clang.c_str(), p_clang_plugin.c_str(), headerfile.c_str());

	std::vector<char> output;
	exec_and_capture_stdout(cmd.c_str(), &output);

	// split output, module info + headers list
	llvm::StringRef output_str(&output[0], output.size());
	std::pair<llvm::StringRef, llvm::StringRef> splitted;
	splitted = output_str.split("-*-");

	// prepare module cache entry
	llvm::SmallVector<llvm::StringRef, 20> deps;
	splitted.second.split(deps, "\n");

	module_cache_t mc;
	prepare_module_cache(&mc, header, deps);

	// prepare input for parser
	output.resize(splitted.first.size());

	// parse
	mini_all_t d;
	parser_t p(&d.srcinfo, &d.diag);
	p.set_input(header, &output);
	d.ast = p.parse();

	if (!d.diag.empty()) {
		d.diag.print_to_stderr(&d.srcinfo);
		DIE("failed to parse C imported module");
	}

	// PASS 1
	pass1_opts_t p1opts = {
		&d.stracker,
		&d.dtracker,
		&d.pkgscope,
		&d.pkgdecls,
		&d.diag,
		&d.ictx
	};
	pass1_t p1(&p1opts);
	p1.pass(d.ast);

	// PASS 2
	pass2_opts_t p2opts = {
		"",
		&d.stracker,
		&d.ttracker,
		&d.dtracker,
		&d.pkgscope,
		&d.diag,
	};
	pass2_t p2(&p2opts);
	p2.pass(&d.pkgdecls);

	if (!d.diag.empty()) {
		d.diag.print_to_stderr(&d.srcinfo);
		DIE("failed to parse C imported module");
	}

	// write library
	bool existed_unused;
	llvm::sys::fs::create_directories(cachedir, existed_unused);
	generate_lib(brlfile.c_str(), &d.pkgdecls, "",
		     llvm::sys::path::stem(header).str().c_str());

	// write cache entry
	write_cache(&mc, cachefile.c_str());
	llvm::sys::fs::remove(headerfile, existed_unused);
	return brlfile;
}
