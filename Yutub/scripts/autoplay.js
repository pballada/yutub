(function(autoplayEnabled) {
    if (typeof yt !== 'undefined' && yt.config_) {
        const isAutoplayEnabled = yt.config_.EXPERIMENT_FLAGS.autoplay_video === autoplayEnabled;
        if (!isAutoplayEnabled) {
            yt.config_.EXPERIMENT_FLAGS.autoplay_video = autoplayEnabled;
        }
    }
})(/*__AUTOPLAY__*/); 