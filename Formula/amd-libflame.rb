class AmdLibflame < Formula
  desc "High-performance object-based library for DLA computations"
  homepage "https://developer.amd.com/amd-aocl"
  head "https://github.com/amd/libflame.git"

  stable do
    url "https://github.com/amd/libflame/archive/2.0.tar.gz"
    sha256 "c80517b455df6763341f67654a6bda909f256a4927ffe9b4f0a2daed487d3739"
    patch :DATA
  end

  depends_on "amd-blis"
  depends_on "gcc" if OS.mac? # for gfortran

  conflicts_with "libflame", :because => "this is an AMD fork of the same library"

  def install
    build_flags = [
      "--disable-debug",
      "--enable-verbose-make-output",
      "--enable-dynamic-build",
      "--enable-lapack2flame",
      "--enable-max-arg-list-hack",
      "--enable-supermatrix",
      "--enable-multithreading=pthreads",
    ]
    if OS.mac? && build.stable?
      inreplace "Makefile", /(SHLIB_EXT\s*:=\s*)so\b/, "\\1dylib"
      inreplace "Makefile", "-shared", "-dynamiclib"
      inreplace "Makefile", "-Wl,-soname", "-Wl,-install_name"
    end
    blis_dir = Formula["amd-blis"].opt_prefix
    ENV.append "LDFLAGS", "-L#{blis_dir}/lib"
    ENV.append "LIBS", "-lblis"
    system "./configure", "--prefix=#{prefix}", *build_flags
    system "make"
    system "make", "install"
  end

  test do
    blis_dir = Formula["amd-blis"].opt_prefix
    blas_flags = ["-I#{blis_dir}/include", "-L#{blis_dir}/lib", "-lblis", "-lm"]
    (testpath/"test.c").write <<~EOS
      #include <FLAME.h>
      int main(int argc, char** argv) {
        char jobu = 'A', jobvt = 'A';
        int m = 2, n = 3, lda = 2, ldu = 2, ldvt = 3, lwork=256;
        double a[6] = {3.0, 2.0, 2.0, 3.0, 2.0, -2.0};
        double s[2], u[2*2], vt[3*3], work[256];
        int info;
        dgesvd_( &jobu, &jobvt, &m, &n, a, &lda, s, u, &ldu, vt, &ldvt, work, &lwork, &info);
        for (int i = 0 ; i < 2 ; ++i) { printf("%lf ", s[i]); }
        printf("\\n");
        if (fabs(s[0]-5) > 1.e-5) abort();
        if (fabs(s[1]-3) > 1.e-5) abort();
        return 0;
      }
    EOS
    system ENV.cc, "-o", "test", "test.c", "-I#{include}", "-L#{lib}", "-lflame", *blas_flags
    system "./test"
  end
end

__END__
diff --git a/Makefile b/Makefile
index d856af4..06bf27b 100644
--- a/Makefile
+++ b/Makefile
@@ -543,7 +543,12 @@ endif
 $(LIBFLAME_SO_PATH): $(MK_ALL_FLAMEC_OBJS)
 ifeq ($(ENABLE_VERBOSE),yes)
 ifeq ($(FLA_ENABLE_MAX_ARG_LIST_HACK),yes)
-	$(LINKER) $(SOFLAGS) -o $@ @$(AR_OBJ_LIST_FILE) $(LDFLAGS)
+	$(CAT) $(AR_OBJ_LIST_FILE) | xargs -n$(AR_CHUNK_SIZE) $(AR) $(ARFLAGS) $(LIBFLAME_A)
+ifeq ($(OS_NAME),Darwin)
+	$(LINKER) $(SOFLAGS) -o $@ -Wl,-force_load,$(LIBFLAME_A) $(LDFLAGS)
+else
+	$(LINKER) $(SOFLAGS) -o $@ -Wl,--whole-archive,$(LIBFLAME_A),--no-whole-archive $(LDFLAGS)
+endif
 else
 #	NOTE: Can't use $^ automatic variable as long as $(AR_OBJ_LIST_FILE) is in
 #	the list of prerequisites.
@@ -552,7 +557,12 @@ endif
 else
 	@echo "Dynamically linking $@"
 ifeq ($(FLA_ENABLE_MAX_ARG_LIST_HACK),yes)
-	@$(LINKER) $(SOFLAGS) -o $@ @$(AR_OBJ_LIST_FILE) $(LDFLAGS)
+	@$(CAT) $(AR_OBJ_LIST_FILE) | xargs -n$(AR_CHUNK_SIZE) $(AR) $(ARFLAGS) $(LIBFLAME_A)
+ifeq ($(OS_NAME),Darwin)
+	@$(LINKER) $(SOFLAGS) -o $@ -Wl,-force_load,$(LIBFLAME_A) $(LDFLAGS)
+else
+	@$(LINKER) $(SOFLAGS) -o $@ -Wl,--whole-archive,$(LIBFLAME_A),--no-whole-archive $(LDFLAGS)
+endif
 else
 #	NOTE: Can't use $^ automatic variable as long as $(AR_OBJ_LIST_FILE) is in
 #	the list of prerequisites.
