{ fetchFromGitHub, stdenv, autoreconfHook, coreutils, gawk
, configFile ? "all"

# Kernel dependencies
, kernel ? null
}:

with stdenv.lib;

let
  buildKernel = any (n: n == configFile) [ "kernel" "all" ];
  buildUser = any (n: n == configFile) [ "user" "all" ];
  common = { version
    , sha256
    , rev ? "spl-${version}"
    } @ args : stdenv.mkDerivation rec {
      name = "spl-${configFile}-${version}${optionalString buildKernel "-${kernel.version}"}";

      src = fetchFromGitHub {
        owner = "zfsonlinux";
        repo = "spl";
        inherit rev sha256;
      };

      patches = [ ./const.patch ./install_prefix.patch ];

      nativeBuildInputs = [ autoreconfHook ];

      hardeningDisable = [ "pic" ];

      preConfigure = ''
        substituteInPlace ./module/spl/spl-generic.c --replace /usr/bin/hostid hostid
        substituteInPlace ./module/spl/spl-generic.c --replace "PATH=/sbin:/usr/sbin:/bin:/usr/bin" "PATH=${coreutils}:${gawk}:/bin"
        substituteInPlace ./module/splat/splat-vnode.c --replace "PATH=/sbin:/usr/sbin:/bin:/usr/bin" "PATH=${coreutils}:/bin"
        substituteInPlace ./module/splat/splat-linux.c --replace "PATH=/sbin:/usr/sbin:/bin:/usr/bin" "PATH=${coreutils}:/bin"
      '';

      configureFlags = [
        "--with-config=${configFile}"
      ] ++ optionals buildKernel [
        "--with-linux=${kernel.dev}/lib/modules/${kernel.modDirVersion}/source"
        "--with-linux-obj=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      ];

      enableParallelBuilding = true;

      meta = {
        description = "Kernel module driver for solaris porting layer (needed by in-kernel zfs)";

        longDescription = ''
          This kernel module is a porting layer for ZFS to work inside the linux
          kernel.
        '';

        homepage = http://zfsonlinux.org/;
        platforms = platforms.linux;
        license = licenses.gpl2Plus;
        maintainers = with maintainers; [ jcumming wizeman wkennington fpletz globin ];
      };
  };
in
  assert any (n: n == configFile) [ "kernel" "user" "all" ];
  assert buildKernel -> kernel != null;
{
    splStable = common {
      version = "0.7.2";
      sha256 = "10rq0npjlp09xjdgn9lc3wm310dqc71j0wgxwj92ncf9r61zf445";
    };

    splUnstable = common {
      version = "2017-09-26";
      rev = "e8474f9ad3b3d23c3277535c4f53f8fd1e6cbd74";
      sha256 = "0251cnffgx98nckgz6imwa8dnvba44wc02aacmr1n430gmq72xra";
    };
}
