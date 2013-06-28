#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <ctype.h>

#include <vector>
using namespace std;

// TODO: add repo (and multi repo in args)

// load 57586 files (56K), 1600408 symbols (1.6M)
// 903M - perl
// 223M - c++ x64, no optimization.
// 162M - c++ x86, no optimization.
// on x64, 1 ptr for symbol means 1.6M*8=12.8M memory.
// optimize SfSymbol structure: 154M - x64; 134M - x86 
// other possible way but less readable: compress "classes" - save 10M; compress "scopes" - save 20M; remove SfSymbol->next pointer: 10M

// test2:
// 1) load 65322 files, 2022655 symbols (19M repo-file)
// perl: 1.1G, 8.1s
// c++ x64: 180M, 0.6s;
// 2) full search 2M symbols > s hello world
// perl: 2.8s
// c++ x64: 0.5s (-O2 0.43s; -g 0.58s)

/* About the design - quick and save memeory.
> why do SfRepoIter/SfFolderIter/SfFileIter/SfSymbolIter have the same base class?
I care about tranverse performance via Next() method. If it's virtual, I'm afraid the tranverse would be a little slow.

> why not a link table of all SfSymbol by "next" pointer?
SfSymbol is linked in a SfFile, because I dont want a SfFile pointer in SfSymbol (save a pointer means 12M memory for 1.6M symbols), then a symbol cannot exist without file.

> why the "nameoff" field in SfSymbol? it is always equal to 0.
Yes, it is useless and just for readable. It does not take any more meory as 4 unsigned short fields take 8B and 3 fields take 8B as well. (structure alignment)

> why not use vector()?
use STL is simple and more readable. But I use my own data structure because: 1. I tested, loading performance decrease 5%-10%, and memory increase <5%; 2. I own all the details and possible to make it  simplest. STL depends on the provider, I cannot control the quality.
*/

// ====== config {{{
int MAX_FOUND = 25;
char EDITOR[100] = "vi";

#ifndef _WINDOWS
char SEP = '/';
#else
char SEP = '\\';
#endif

#define HELPSTR "\
f {patterns} \n\
  file search \n\
s {patterns} \n\
  symbol search \n\
go [num=1] \n\
  open the {num}th result  \n\
n/N \n\
  go next or previous \n\
max [num=25] \n\
  set max displayed result \n\
editor [prog=vi] \n\
  set default viewer for go. \n\
replace [old=new] \n\
  replace the real path from \"old\" to \"new\" \n\
? \n\
  show this help. \n\
q \n\
  quit \n\
 \n\
-------- hint for pattern: \n\
end with / - find file in dir \n\
begin with # - search symbol that value matches the pattern \n\
f|t|...  - find symbol of kind=f or t ... \n\
"

//}}}

// ====== structure {{{
// ==== basic {{{
struct SfSymbol
{
// 	char *name;
// 	char *line;
// 	char *file;
// 	char *kind;
// 	char *extra;

	// actually offset from buf
	unsigned short nameoff, lineoff, kindoff, extraoff;
	SfSymbol *next;
	char buf[0];

	char *name() { return buf+nameoff; }
	char *line() { return buf+lineoff; }
	char *kind() { return buf+kindoff; }
	char *extra() { return buf+extraoff; }
};

struct SfFile
{
	char *name;
	SfSymbol *symbols;
	SfFile *next;
};

struct SfFolder
{
	char *name;
	SfFile *files;
	SfFolder *next;
};

struct SfRepo
{
	char *root;
	SfFolder *folders;
	SfRepo *next;
};
// }}}

// ==== iteratoers {{{
struct SfContext
{
	SfRepo *repo;
	SfFolder *folder;
	SfFile *file;
	SfSymbol *symbol;
};

class SfRepoIter
{
public:
	SfRepoIter(SfRepo *repo) {
		m_vrepo.next = repo;
		memset(&m_ctx, 0, sizeof(SfContext));
		m_ctx.repo = &m_vrepo;
	}
	SfRepo *Next() {
		if (m_ctx.repo)
			m_ctx.repo = m_ctx.repo->next;
		return m_ctx.repo;
	}
	SfRepo *Value() const { return m_ctx.repo; }

	const SfContext &GetContext() const {
		return m_ctx;
	}
protected:
	SfRepo m_vrepo; // a virutal head
	SfContext m_ctx;
};

struct SfFolderIter: public SfRepoIter
{
	SfFolderIter(SfRepo *repo): SfRepoIter(repo) {
	}
	SfFolder *Next() {
		if (m_ctx.folder && m_ctx.folder->next)
			m_ctx.folder = m_ctx.folder->next;
		else
			m_ctx.folder = NextLink();
		return m_ctx.folder;
	}
	SfFolder *Value() const { return m_ctx.folder; }

private:
	SfFolder *NextLink() {
		SfRepo *repo;
		while (repo = SfRepoIter::Next()) {
			if (repo->folders)
				break;
		}
		return repo? repo->folders: NULL;
	}
};

struct SfFileIter: public SfFolderIter
{
	SfFileIter(SfRepo *repo): SfFolderIter(repo) {
	}
	SfFile *Next() {
		if (m_ctx.file && m_ctx.file->next)
			m_ctx.file = m_ctx.file->next;
		else 
			m_ctx.file = NextLink();
		return m_ctx.file;
	}
	SfFile *Value() const { return m_ctx.file; }

private:
	SfFile *NextLink() {
		SfFolder *folder;
		while (folder = SfFolderIter::Next()) {
			if (folder->files)
				break;
		}
		return folder? folder->files: NULL;
	}
};

struct SfSymbolIter: public SfFileIter
{
	SfSymbolIter(SfRepo *repo): SfFileIter(repo) {
	}
	SfSymbol *Next() {
		if (m_ctx.symbol && m_ctx.symbol->next)
			m_ctx.symbol = m_ctx.symbol->next;
		else
			m_ctx.symbol = NextLink();
		return m_ctx.symbol;
	}
	SfSymbol *Value() { return m_ctx.symbol; }

private:
	SfSymbol *NextLink() {
		SfFile *file;
		while (file = SfFileIter::Next()) {
			if (file->symbols)
				break;
		}
		return file? file->symbols: NULL;
	}
};

// }}}

// ==== others {{{
struct FindResult
{
	char kind; // 'f','s'
	vector<SfContext> items;
	int curidx;

	void Init(char kind) {
		this->kind = kind;
		items.clear();
		curidx = -1;
	}
};

struct RootSubs
{
	char pattern[500];

	RootSubs(const char *pattern = "") {
		Set(pattern);
	}
	
	void Set(const char *pattern) {
		strcpy(m_buf, pattern);
		char *p = m_buf, *p1 = m_buf, *p2 = NULL;
		m_subs.clear();
		for (; ; ++p) {
			if (*p == '=') {
				*p++ = 0;
				p2 = p;
			}
			else if (*p == ';' || *p == 0) {
				if (*p1 && p2 && *p2)
					m_subs.push_back(make_pair(p1, p2));
				if (*p == 0)
					break;
				*p++ = 0;
				p1 = p;
				p2 = NULL;
			}
		}
		if (m_subs.size() > 0)
			strcpy(this->pattern, pattern);
		else
			strcpy(this->pattern, "(empty)");
	}
	const char *Substitue(const char *s) {
		static char buf[1024];
		for (auto &sub: m_subs) {
			const char *p = strstr(s, sub.first);
			if (p) {
				sprintf(buf, "%.*s%s%s", p-s, s, sub.second, p+strlen(sub.first));
				return buf;
			}
		}
		return s;
	}
private:
	char m_buf[500];
	vector<pair<char*, char*> > m_subs;
};
// }}}
// }}}

// ====== global {{{
SfRepo *g_repos;
FindResult g_result;
RootSubs g_rootsubs;

bool g_forsvr = getenv("SYM_SVR") != NULL;

//}}}

// ====== toolkit {{{
#define ALLOC_T(T) (T*)malloc(sizeof(T))
#define ALLOC_N(T, N) (T*)malloc(sizeof(T)*N)
#define CALLOC_T(T) (T*)calloc(1, sizeof(T))
#define FREE(p) free(p)

#ifdef _WINDOWS
#include <windows.h>
void sleep(int sec)
{
	Sleep(sec * 1000);
}
#endif

bool BeginWith_icase(const char *s1, const char *s2)
{
	bool ok = true;
	for (; *s1 && *s2; ++ s1, ++ s2) {
		if (toupper(*s1) != toupper(*s2)) { // case-insensitive
			ok = false;
			break;
		}
	}
	return ok && *s2 == 0;
}

bool BeginWith_case(const char *s1, const char *s2)
{
	bool ok = true;
	for (; *s1 && *s2; ++ s1, ++ s2) {
		if (*s1 != *s2) { // case-sensitive
			ok = false;
			break;
		}
	}
	return ok && *s2 == 0;
}

// }}}

// ====== functions {{{
void Help()
{
	fputs(HELPSTR, stdout);
}

// ==== load repo {{{
unsigned short strtok_offset(char *s, const char *sep, char *base)
{
#ifdef _WINDOWS
	static char *pn;
	if (s)
		pn = strchr(s, 0);
	char *p = strtok(s, sep);
	return p? p-base: pn-base;
#else
	static char *pn;
	char *p = strtok_r(s, sep, &pn);
	return p? p-base: pn-base;
#endif
}

SfSymbol *NewSymbol(char *buf) 
{
	int len = sizeof(SfSymbol) + strlen(buf) +1;
	char *p = ALLOC_N(char, len);
	SfSymbol *sym = (SfSymbol*)p;
	char *p1 = p + sizeof(SfSymbol);
	strcpy(p1, buf);

	const char *sep = "\t\r\n";
	sym->nameoff = strtok_offset(p1, sep, p1);
	sym->lineoff = strtok_offset(NULL, sep, p1);
	sym->kindoff = strtok_offset(NULL, sep, p1);
	sym->extraoff = strtok_offset(NULL, sep, p1);
	return sym;
}

#define EndSymbol() \
	if (pSymbol) \
		*pSymbol = NULL; \
	pSymbol = NULL

#define EndFile() \
	if (pFile) \
		*pFile = NULL; \
	pFile = NULL; \
	EndSymbol()

#define EndFolder() \
	if (pFolder) \
		*pFolder = NULL; \
	pFolder = NULL; \
	EndFile()

#define EndRepo(repo) \
	if (pRepo) \
		*pRepo = NULL; \
	pRepo = NULL; \
	EndFolder()

int LoadRepofile(FILE *fp)
{
	clock_t t0 = clock();
	char buf[1024];
	bool ismeta = false;
	SfRepo **pRepo = &g_repos;
	SfFolder **pFolder = NULL;
	SfFile **pFile = NULL;
	SfSymbol **pSymbol = NULL;

	int scnt = 0, fcnt = 0;
	while (fgets(buf, 1024, fp)) {
		if (buf[0] == '!') {
			char *p = buf+1;
			if (strncmp(p, "ROOT ", 5) == 0) {
				if (!ismeta) {
					p += 5;
					SfRepo *repo = CALLOC_T(SfRepo);
					repo->root = strdup(strtok(p, " \r\n"));
					if (strchr(repo->root, '/') != NULL) {
						SEP = '/';
					}
					else if (strchr(repo->root, '\\') != NULL) {
						SEP = '\\';
					}

					*pRepo = repo;
					pRepo = &repo->next;

					EndFolder();
					pFolder = &repo->folders;
				}
				ismeta = true;
			}
			continue;
		}
		ismeta = false;

		// "  d/f  <name>  <time>"
		if (buf[0] == '\t' && buf[2] == '\t') {
			char *value = strtok(buf+3, "\t");
			if (buf[1] == 'd') {
				if (pFolder == NULL) {
					printf("*** bad format (no repo before folder)!\n");
					exit(-1);
				}
				SfFolder *folder = CALLOC_T(SfFolder);
				folder->name = strdup(value);

				*pFolder = folder;
				pFolder = &folder->next;

				EndFile();
				pFile = &folder->files;
			}
			else if (buf[1] == 'f') {
				if (pFile == NULL) {
					printf("*** bad format! (no folder before file)\n");
					exit(-1);
				}

				SfFile *file = CALLOC_T(SfFile);
				file->name = strdup(value);

				*pFile = file;
				pFile = &file->next;
				++ fcnt;

				EndSymbol();
				pSymbol = &file->symbols;
			}
		}
		else { // symbol
			if (pSymbol == NULL) {
				printf("*** bad format! (no file before symbol)\n");
				exit(-1);
			}

			SfSymbol *symbol = NewSymbol(buf);

			*pSymbol = symbol;
			pSymbol = &symbol->next;
			++ scnt;
		}
	}
	EndRepo();
	printf("load %d files, %d symbols in %.3fs.\n", fcnt, scnt, (double)(clock()-t0)/CLOCKS_PER_SEC);
	return 0;
}

void FreeRepos()
{
	void *p;
	for (SfRepo *repo = g_repos; repo; ) {
		for (SfFolder *folder = repo->folders; folder; ) {
			for (SfFile *file = folder->files; file; ) {
				for (SfSymbol *symbol = file->symbols; symbol; ) {
					p = symbol;
					symbol = symbol->next;
					FREE(p);
				}
				FREE(file->name);
				p = file;
				file = file->next;
				FREE(p);
			}
			FREE(folder->name);
			p = folder;
			folder = folder->next;
			FREE(p);
		}
		FREE(repo->root);
		p = repo;
		repo = repo->next;
		FREE(p);
	}
	g_repos = NULL;
}

// }}}

// ==== search files and symbols {{{
struct SfPattern
{
	const char *pat;
	bool matchBegin, matchEnd;
	int patlen;
	bool (SfPattern::*fnMatch)(const char *s);
	
	SfPattern(char *pat) {
		matchBegin =false;
		matchEnd = false;
		patlen = 0;

		char *p = pat;
		if (*p == '^') {
			++ p;
			matchBegin = true;
		}
		char *p1 = strchr(p, 0);
		if (p1 > p && *(p1-1) == '$') {
			*--p1 = 0;
			matchEnd = true;
		}
		patlen = p1 -p;
		this->pat = p;

		fnMatch = &SfPattern::Match_icase;
		for (; *p; ++p) {
			if (isupper(*p)) {
				fnMatch = &SfPattern::Match_case;
				break;
			}
		}
	}
	bool Match(const char *s) {
		return (this->*fnMatch)(s);
	}
	bool Match_icase(const char *s) {
		if (patlen <= 0)
			return true;
		int slen = strlen(s);
		if (slen < patlen)
			return false;

		if (matchBegin || matchEnd) {
			return BeginWith_icase((matchBegin? s: s+slen-patlen), pat);
		}
		else {
			for (; *s; ++s) {
				if (toupper(*s) == toupper(*pat) && BeginWith_icase(s+1, pat+1))
					return true;
			}
		}
		return false;
	}
	bool Match_case(const char *s) {
		if (patlen <= 0)
			return true;
		int slen = strlen(s);
		if (slen < patlen)
			return false;

		if (matchBegin || matchEnd) {
			return BeginWith_case((matchBegin? s: s+slen-patlen), pat);
		}
		else {
			for (; *s; ++s) {
				if (*s == *pat && BeginWith_case(s+1, pat+1))
					return true;
			}
		}
		return false;
	}
};
typedef vector<SfPattern> SfPatterns;

char *GetFullName(char *buf, const char *root, const char *dirname, const char *file = NULL)
{
// 	static char buf[1024];
	// 1. replace root
	root = g_rootsubs.Substitue(root);

	char quote[2] = {0,0};
	if (file && (strchr(root, ' ') != NULL || strchr(dirname, ' ') != NULL || strchr(file, ' ') != NULL))
		quote[0] = '"';

	// 2. remove ./ at the beginning of dirname
	const char *p = dirname;
	if (*p == '.') {
		++ p;
		if (*p == '/' || *p == '\\') // './xxx'
		{
			++p;
			dirname = p;
		}
		else if (*p == 0) // '.'
			dirname = p;
	}
	if (dirname[0] == 0) {
		if (file == NULL)
			sprintf(buf, "%s%s%s", quote, root, quote);
		else 
			sprintf(buf, "%s%s%c%s%s", quote, root, SEP, file, quote);
	}
	else {
		if (file == NULL)
			sprintf(buf, "%s%s%c%s%s", quote, root, SEP, dirname, quote);
		else 
			sprintf(buf, "%s%s%c%s%c%s%s", quote, root, SEP, dirname, SEP, file, quote);
	}
	return buf;
}

void QueryFile(char *arg)
{
	SfFileIter it(g_repos);
	SfPatterns pats, pats_dir;

	char *p;
	while (p = strtok(arg, " ")) {
		arg = NULL; // make strtok contine
		char *p1 = strchr(p, 0)-1;
		SfPatterns *ppats = &pats;
		if (*p1 == '/' || *p1 == '\\') {
			*p1 -- = 0;
			ppats = &pats_dir;
		}
		ppats->push_back(SfPattern(p));
	}

	g_result.Init('f');
	while (it.Next()) {
		const SfContext &ctx = it.GetContext();
		char *name = ctx.file->name;
		bool ok = true;
		for (SfPattern &pat: pats) {
			if (! pat.Match(name)) {
				ok = false;
				break;
			}
		}
		if (ok && pats_dir.size() > 0) {
			name = ctx.folder->name;
			for (SfPattern &pat: pats_dir) {
				if (! pat.Match(name)) {
					ok = false;
					break;
				}
			}
		}
		if (ok) {
			auto &items = g_result.items;
			items.push_back(ctx);
			int cnt = items.size();
			char buf[1024];
			printf("%d:\t%s\t%s\n", cnt, ctx.file->name, GetFullName(buf, ctx.repo->root, ctx.folder->name));
			if (cnt >= MAX_FOUND) {
				printf("... (max %d)\n", MAX_FOUND);
				break;
			}
		}
	}
}

void QuerySymbol(char *arg)
{
	SfSymbolIter it(g_repos);

	char pat_kind[20] = {0};
	char kindlen = 0;
	vector<SfPattern> pats, pats_val;

	char *p;
	while (p = strtok(arg, " ")) {
		arg = NULL; // make strtok continue

		if (*(p+1) == 0) { // only 1 char for pat_kind
			if (kindlen < sizeof(pat_kind))
				pat_kind[kindlen++] = *p;
			continue;
		}

		SfPatterns *ppats = &pats;
		if (*p == '#') {
			++ p;
			ppats = &pats_val;
		}
		ppats->push_back(SfPattern(p));
	}

	g_result.Init('s');
	while (it.Next()) {
		SfSymbol *symbol = it.Value();

		char *name = symbol->name();
		bool ok = true;

		char *kind = symbol->kind();
		if (kindlen && strncmp(kind, pat_kind, kindlen) != 0)
			continue;

		for (SfPattern &pat: pats) {
			if (! pat.Match(name)) {
				ok = false;
				break;
			}
		}
		if (ok && pats_val.size() > 0) {
			ok = strcmp(kind, "macro") == 0 || strcmp(kind, "variable") == 0;
			if (ok) {
				char *extra = symbol->extra();
				for (SfPattern &pat: pats_val) {
					if (! pat.Match(extra)) {
						ok = false;
						break;
					}
				}
			}
		}
		if (ok) {
			auto &items = g_result.items;
			const SfContext &ctx = it.GetContext();
			items.push_back(ctx);
			int cnt = items.size();
			char buf[1024];
			if (!g_forsvr)
				printf("%d:\t%s\t%s\t%s\t%s:%s\n", cnt, kind, symbol->name(), symbol->extra(), ctx.file->name, symbol->line());
			else
				printf("%d:\t%s\t%s\t%s\t%s:%s\t%s\n", cnt, kind, symbol->name(), symbol->extra(), ctx.file->name, symbol->line(), 
						GetFullName(buf, ctx.repo->root, ctx.folder->name));
			if (cnt >= MAX_FOUND) {
				printf("... (max %d)\n", MAX_FOUND);
				break;
			}
		}
	}
}

void GotoResult(const char *cmd, const char *arg)
{
	int idx = g_result.curidx;
	if (arg == NULL) {
		if (cmd[0] == 'N')
			-- idx;
		else
			++ idx;
	}
	else {
		idx = atoi(arg)-1;
	}
	if (idx >= 0 && idx < g_result.items.size()) {
		g_result.curidx = idx;
		
		char buf[1024], *p = buf;
		p += sprintf(p, "%s ", EDITOR);

		const SfContext &ctx = g_result.items[idx];
		const char *line = g_result.kind == 's'? ctx.symbol->line(): NULL;
		if (line) {
			p += sprintf(p, "+%s ", line);
		}
		GetFullName(p, ctx.repo->root, ctx.folder->name, ctx.file->name);
		printf("go %d: %s\n", idx+1, buf);
		system(buf);
	}
}
//}}}

int TestShow()
{
	// Test code for tranverse objects
	int maxcnt = 40;
	int i;
	char buf[1024];
	printf("=== folders:\n");
	SfFolderIter itFolder(g_repos);
	for (i=0; i<maxcnt && itFolder.Next(); ++i) {
		const SfContext &ctx = itFolder.GetContext();
		printf("%d: %s\n", i+1, GetFullName(buf, ctx.repo->root, ctx.folder->name));
	}
	printf("=== files:\n");
	SfFileIter itFile(g_repos);
	for (i=0; i<maxcnt && itFile.Next(); ++i) {
		const SfContext &ctx = itFile.GetContext();
		printf("%d: %s\n", i+1, GetFullName(buf, ctx.repo->root, ctx.folder->name, ctx.file->name));
	}
	printf("=== symbols:\n");
	SfSymbolIter itSymbol(g_repos);
	for (i=0; i<maxcnt && itSymbol.Next(); ++i) {
		const SfContext &ctx = itSymbol.GetContext();
		printf("%d: %s\t%s\t%s\t%s:%s\n", i+1, ctx.symbol->kind(), ctx.symbol->name(), ctx.symbol->extra(), GetFullName(buf, ctx.repo->root, ctx.folder->name, ctx.file->name), ctx.symbol->line());
	}
	return 0;
}
// }}}

// ====== main routine {{{
int main(int argc, char *argv[])
{
	if (argc <= 1) {
		printf("Usage: symfind <repo>\n");
		return -1;
	}
	if (g_forsvr) {
		fputs("(for symsvr)\n", stdout);
		setbuf(stdout, NULL);
		setbuf(stderr, NULL);
	}
	char buf[1024];
	sprintf(buf, "gzip -dc \"%s\"", argv[1]);
// 	printf("cmd: '%s'\n", buf);
	FILE *fp = popen(buf, "r");
	if (fp == NULL) {
		printf("*** cannot open repo-file \"%s\"!\n", argv[1]);
	}
	printf("=== loading %s...\n", argv[1]);
	LoadRepofile(fp);
	pclose(fp);

// 	printf("for attach (pid=%d)...\n", getpid());
// 	sleep(10);

	// !!! to debug the loading and iterator, run: $ SF_TEST=1 symfind 1.repo.gz
	if (getenv("SF_TEST") != NULL)
		return TestShow();

	fputs("> ", stdout);
	if (g_forsvr)
		fputs("\n", stdout);
	while (fgets(buf, 1024, stdin)) {
		char *cmd = strtok(buf, " \r\n");
		char *arg = strtok(NULL, "\r\n");
		if (strcmp(cmd, "f") == 0 || strcmp(cmd, "s") == 0) {
			clock_t t0 = clock();
			if (cmd[0] == 'f')
				QueryFile(arg);
			else // 's'
				QuerySymbol(arg);
			printf("(Total %d result(s) in %.3fs.)\n", g_result.items.size(), (double)(clock()-t0)/CLOCKS_PER_SEC);
		}
		else if (strcmp(cmd, "q") == 0) {
			break;
		}
		else if (strcmp(cmd, "?") == 0) {
			Help();
		}
		else if (!g_forsvr && (strcmp(cmd, "go") == 0 || strcmp(cmd, "n") == 0 || strcmp(cmd, "N") == 0)) {
			GotoResult(cmd, arg);
		}
		else if (strcmp(cmd, "editor") == 0) {
			if (arg) {
				strcpy(EDITOR, arg);
			}
			printf("editor %s\n", EDITOR);
		}
		else if (strcmp(cmd, "max") == 0) {
			if (arg) {
				int n = atoi(arg);
				if (n > 0) {
					MAX_FOUND = n;
				}
			}
			printf("max %d\n", MAX_FOUND);
		}
		else if (strcmp(cmd, "root") == 0) {
			if (arg) {
				g_rootsubs.Set(arg);
			}
			printf("root %s\n", g_rootsubs.pattern);
		}
		else {
			printf("*** unknown command: '%s'. Type '?' for help.\n", cmd);
		}
		printf("> ");
		if (g_forsvr)
			fputs("\n", stdout);
	}
	FreeRepos();
	
	return 0;
}
// }}}
// vim: set foldmethod=marker :
