(function(isDarkMode) {
    const isDarkModeEnabled = document.body.getAttribute('dark') === 'true';
    if (isDarkModeEnabled !== isDarkMode) {
        document.body.setAttribute('dark', isDarkMode ? 'true' : 'false');
        if (typeof yt !== 'undefined' && yt.config_) {
            yt.config_.EXPERIMENT_FLAGS.web_dark_theme = isDarkMode;
            if (yt.config_.WEB_PLAYER_CONTEXT_CONFIGS && yt.config_.WEB_PLAYER_CONTEXT_CONFIGS['WEB_PLAYER_CONTEXT_ID_KEBAB']) {
                yt.config_.WEB_PLAYER_CONTEXT_CONFIGS['WEB_PLAYER_CONTEXT_ID_KEBAB'].webPlayerContextConfig.darkTheme = isDarkMode;
            }
        }
    }
})(/*__DARK_MODE__*/); 