import Toybox.Application;
import Toybox.WatchUi;

class PowerZonesApp extends Application.AppBase {

    var mView = null;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        mView = new PowerZonesView();
        return [mView];
    }

    function onSettingsChanged() {
        if (mView != null) {
            mView.loadSettings();
        }
        WatchUi.requestUpdate();
    }
}
