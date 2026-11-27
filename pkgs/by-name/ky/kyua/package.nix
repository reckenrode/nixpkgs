{
  lib,
  stdenv,
  fetchFromGitHub,
  atf,
  autoreconfHook,
  lutok,
  pkg-config,
  sqlite,
  unstableGitUpdater,
  which,
}:

let
  # Avoid an infinite recursion (because ATF uses Kyua for testing).
  atf' = atf.overrideAttrs (_: {
    doInstallCheck = false;
  });
in
stdenv.mkDerivation (finalAttrs: {
  pname = "kyua";
  version = "0.15.2";

  src = fetchFromGitHub {
    owner = "freebsd";
    repo = "kyua";
    tag = "kyua-${finalAttrs.version}";
    hash = "sha256-Q+ciDOrI3AWr8PRUfUaHOn9u/jsTinhtbqEiKyiL3Pg=";
  };

  setupHooks = ./kyua-check-hook.sh;

  postPatch =
  # These tests fail on Darwin or are unreliable.
  lib.optionalString (finalAttrs.doInstallCheck && stdenv.hostPlatform.isDarwin) ''
    substituteInPlace engine/atf_test.cpp \
      --replace-fail 'ATF_ADD_TEST_CASE(tcs, test__body_only__crashes);' ""
    substituteInPlace engine/googletest_test.cpp \
      --replace-fail 'ATF_ADD_TEST_CASE(tcs, test__body_only__crashes);' ""
    substituteInPlace engine/scheduler_test.cpp \
      --replace-fail 'ATF_ADD_TEST_CASE(tcs, integration__stacktrace);' ""
    substituteInPlace utils/stacktrace_test.cpp \
      --replace-fail 'ATF_ADD_TEST_CASE(tcs, unlimit_core_size);' ""
    substituteInPlace utils/process/isolation_test.cpp \
      --replace-fail 'ATF_ADD_TEST_CASE(tcs, isolate_child__enable_core_dumps);' ""
    substituteInPlace utils/process/operations_test.cpp \
      --replace-fail 'ATF_ADD_TEST_CASE(tcs, terminate_self_with__termsig_and_core);' ""
    substituteInPlace utils/process/status_test.cpp \
      --replace-fail 'ATF_ADD_TEST_CASE(tcs, integration__coredump);' ""
  ''
  # fchflags and UF_NOUNLINK are not supported on Linux. Other tests also fail.
  + lib.optionalString (finalAttrs.doInstallCheck && stdenv.hostPlatform.isLinux) ''
    # sed -i utils/process/Makefile.am.inc -e '/executor_pid_test/d'
    # substituteInPlace utils/process/Kyuafile \
    #   --replace-fail 'atf_test_program{name="executor_pid_test"}' ""
    # substituteInPlace engine/atf_test.cpp \
    #   --replace-fail 'ATF_ADD_TEST_CASE(tcs, test__body_only__crashes);' ""
    # substituteInPlace utils/stacktrace_test.cpp \
    #   --replace-fail 'ATF_ADD_TEST_CASE(tcs, dump_stacktrace__ok);' "" \
    #   --replace-fail 'ATF_ADD_TEST_CASE(tcs, dump_stacktrace_if_available__append);' "" \
    #   --replace-fail 'ATF_ADD_TEST_CASE(tcs, find_core__found__long);' "" \
    #   --replace-fail 'ATF_ADD_TEST_CASE(tcs, find_core__found__short);' "" \
    #   --replace-fail 'ATF_ADD_TEST_CASE(tcs, unlimit_core_size__hard_is_zero);' ""
    # substituteInPlace integration/cmd_test_test.sh \
    #   --replace-fail 'atf_add_test_case premature_exit' ""
  '';

  strictDeps = true;

  buildInputs = [
    lutok
    sqlite
  ];

  nativeBuildInputs = [
    atf'
    autoreconfHook
    pkg-config
  ];

  configureFlags = lib.optionals finalAttrs.finalPackage.doInstallCheck [
    (lib.enableFeature true "atf")
  ];

  enableParallelBuilding = true;

  doInstallCheck = true;

  installCheckInputs = [ atf' ];
  nativeInstallCheckInputs = [ sqlite which ];

  installCheckPhase = ''
    runHook preInstallCheck
    HOME=$TMPDIR PATH=$out/bin:$PATH kyua test
    runHook postInstallCheck
  '';

  passthru.updateScript = unstableGitUpdater { tagPrefix = "kyua-"; };

  __structuredAttrs = true;

  meta = {
    description = "Testing framework for infrastructure software";
    homepage = "https://github.com/freebsd/kyua/";
    changelog = "https://github.com/freebsd/kyua/blob/master/NEWS.md";
    license = lib.licenses.bsd3;
    mainProgram = "kyua";
    maintainers = with lib.maintainers; [ reckenrode ];
    platforms = lib.platforms.unix;
  };
})
