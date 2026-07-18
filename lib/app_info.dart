const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.3.0');
const appReleaseBuild =
    int.fromEnvironment('APP_RELEASE_BUILD', defaultValue: 0);
const appVersionLabel =
    appReleaseBuild == 0 ? appVersion : '$appVersion（$appReleaseBuild）';
