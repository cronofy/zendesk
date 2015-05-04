(function ($) {

    var $pulses      = $('.app-pulses');
    var $steps       = $('.app-graphic__step');
    var animClass    = 'animated';
    var animTime     = 11000;
    var fadeOutClass = 'fadeOut';

    /**
     * Kick it off 1 second after page load.
     */
    setTimeout(function () {
        runAnimation($pulses);
    }, 1000);

    /**
     * Run the main animation forever.
     */
    function runAnimation() {
        $steps.addClass(animClass);
        $pulses.addClass(animClass);
        setTimeout(function () {
            $pulses.removeClass(animClass);
            $steps.addClass(fadeOutClass);
            setTimeout(function () {
                $steps.removeClass([animClass, fadeOutClass].join(' '));
            }, 1000);
            setTimeout(function () {
                runAnimation();
            }, 2000);
        }, animTime);
    }

})(jQuery);