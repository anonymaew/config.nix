{...}: {
  program.git = {
    enable = true;
    settings.user = {
      name = "Napat Srichan";
      email = "me@napatsc.com";
    };
    signing = {
      signByDefault = true;
      format = "openpgp";
      key = "74C4 EA31 DDE9 7553 0A15  B036 A46D 60E5 7550 D198";
    };
  };
}
