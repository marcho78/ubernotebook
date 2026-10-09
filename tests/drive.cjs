// Runs the files helper (bin/uber-notebook-files) as on a drive that can't
// keep files private, in a folder of the test's own:
//   "exfat"   every file it makes reads 644, every folder 755, and a chmod
//             changes nothing (an exFAT or FAT partition mounted umask=022)
//   "files"   folders as asked, files 644 whatever's asked, and a chmod
//             changes nothing (a share)
//   "refuses" a chmod refused, "Operation not supported" (a phone, through
//             gvfs)
//   "notmine" modes kept, but every folder's owner another account (a share
//             that takes every account for the same one)
// helperOn(drive, args, input) -> { code, out, err }.
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const helper = path.join(__dirname, "..", "bin", "uber-notebook-files");

const PRELUDE = [
  "import errno, os, runpy, stat, sys",
  "drive = sys.argv[1]",
  "real_open, real_mkdir, real_fchmod, real_fstat = os.open, os.mkdir, os.fchmod, os.fstat",
  "def fstat(fd):",
  "    st = real_fstat(fd)",
  "    if drive == 'notmine' and stat.S_ISDIR(st.st_mode):",
  "        t = list(st[:10]); t[4] = st.st_uid + 1",
  "        return os.stat_result(t)",
  "    return st",
  "def fchmod(fd, mode):",
  "    if drive == 'refuses':",
  "        raise OSError(errno.ENOTSUP, 'Operation not supported')",
  "def open_(path, flags, mode=0o777, *, dir_fd=None):",
  "    fd = real_open(path, flags, mode, dir_fd=dir_fd)",
  "    if flags & os.O_CREAT and drive in ('exfat', 'files'):",
  "        real_fchmod(fd, 0o644)",
  "    return fd",
  "def mkdir(path, mode=0o777, *, dir_fd=None):",
  "    real_mkdir(path, mode, dir_fd=dir_fd)",
  "    if drive == 'exfat':",
  "        os.chmod(path, 0o755, dir_fd=dir_fd)",
  "os.fchmod, os.open, os.mkdir, os.fstat = fchmod, open_, mkdir, fstat",
  // (Still taking dir_fd, as shutil.rmtree looks for.)
  "os.supports_dir_fd.update((open_, mkdir))",
  "sys.argv = sys.argv[2:]",
  "runpy.run_path(sys.argv[0], run_name='__main__')",
].join("\n");

function helperOn(drive, args, input) {
  const r = spawnSync("/usr/bin/python3", ["-I", "-S", "-c", PRELUDE, drive, helper].concat(args), { encoding: "utf8", input: input === undefined ? "" : input, timeout: 30000 });
  return { code: r.status, out: r.stdout, err: r.stderr };
}

module.exports = { helperOn };
