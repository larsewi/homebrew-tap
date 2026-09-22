class Leech2 < Formula
  desc "Track CSV changes and produce SQL patches"
  homepage "https://github.com/larsewi/leech2"
  license "MIT"

  depends_on :macos

  on_arm do
    url "https://github.com/larsewi/leech2/releases/download/v5.5.2/leech2-5.5.2-macos-aarch64.tar.gz"
    sha256 "9e514b441dbb1d1269d92ccbd1509a774acb1ceb8fe228377c3937383b3dbf4e"
  end

  on_intel do
    url "https://github.com/larsewi/leech2/releases/download/v5.5.2/leech2-5.5.2-macos-x86_64.tar.gz"
    sha256 "33b3d7292344cda968b3c99743f74ec160df787d76c9ffc4b44b8603c4d95e56"
  end

  livecheck do
    url :homepage
    strategy :github_latest
  end

  def install
    bin.install "lch"
    lib.install "libleech2.dylib"
    include.install "leech2.h"
    man1.install Dir["man/*.1"]
    man3.install Dir["man/*.3"]
    doc.install "README.md", "LICENSE"

    # The tarball ships a relocatable @rpath install name. Point it at the keg
    # so consumers can link with -lleech2 without setting an rpath themselves.
    # install_name_tool invalidates the signature, so sign it again.
    system "install_name_tool", "-id", "#{lib}/libleech2.dylib", "#{lib}/libleech2.dylib"
    system "codesign", "--force", "--sign", "-", "#{lib}/libleech2.dylib"

    inreplace "leech2.pc.in" do |s|
      s.gsub! "@PREFIX@", opt_prefix
      s.gsub! "@LIBDIR@", "lib"
      s.gsub! "@VERSION@", version.to_s
    end
    (lib/"pkgconfig").install "leech2.pc.in" => "leech2.pc"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/lch --version")

    # 'lch init' seeds a work directory with an example table, so the whole
    # pipeline runs without any fixtures.
    system bin/"lch", "init"
    system bin/"lch", "block", "create"
    system bin/"lch", "patch", "create"
    assert_predicate testpath/".leech2/state", :directory?
    assert_match "INSERT INTO \"products\"", shell_output("#{bin}/lch patch sql")

    (testpath/"smoke.c").write <<~C
      #include <leech2.h>
      #include <stdio.h>
      #include <stdlib.h>

      int main(void)
      {
          printf("%s\\n", lch_version());
          return EXIT_SUCCESS;
      }
    C
    system ENV.cc, "smoke.c", "-I#{include}", "-L#{lib}", "-lleech2", "-o", "smoke"
    assert_equal version.to_s, shell_output("./smoke").strip
  end
end
