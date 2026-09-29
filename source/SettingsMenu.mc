import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// On-device settings: Edge > data screens > this field > Connect IQ settings.
// Numbers are entered digit by digit so the exact value can be set quickly.

function readSetting(key, def) {
    var v = null;
    try {
        v = Application.Properties.getValue(key);
    } catch (e) {
        v = null;
    }
    if (v instanceof Number) {
        return v;
    }
    return def;
}

function writeSetting(key, value) {
    Application.Properties.setValue(key, value);
    Application.getApp().onSettingsChanged();
}

function buildSettingsMenu() {
    var menu = new WatchUi.Menu2({:title => WatchUi.loadResource(Rez.Strings.MenuTitle) + " b" + BUILD_NUMBER});
    menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SetFtp),
        readSetting("ftp", 295).toString() + " W", :ftp, null));
    menu.addItem(new WatchUi.ToggleMenuItem(WatchUi.loadResource(Rez.Strings.MenuRangePct),
        null, :rangeUnits, readSetting("rangeUnits", 0) == 1, null));
    menu.addItem(new WatchUi.ToggleMenuItem(WatchUi.loadResource(Rez.Strings.MenuLastPct),
        null, :lastField, readSetting("lastField", 0) == 1, null));
    return [menu, new SettingsMenuDelegate()];
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == :ftp) {
            pushNumberPicker(item, "ftp", WatchUi.loadResource(Rez.Strings.SetFtp), 295, 50, 999, " W");
        } else if (id == :rangeUnits || id == :lastField) {
            var on = (item as WatchUi.ToggleMenuItem).isEnabled();
            writeSetting(id == :rangeUnits ? "rangeUnits" : "lastField", on ? 1 : 0);
        }
    }

    function pushNumberPicker(item, key, title, def, minV, maxV, unit) {
        var v = readSetting(key, def);
        var digits = [(v / 100) % 10, (v / 10) % 10, v % 10];
        var factory = new DigitFactory();
        var picker = new WatchUi.Picker({
            :title => new WatchUi.Text({
                :text => title,
                :locX => WatchUi.LAYOUT_HALIGN_CENTER,
                :locY => WatchUi.LAYOUT_VALIGN_BOTTOM,
                :color => Graphics.COLOR_WHITE
            }),
            :pattern => [factory, factory, factory],
            :defaults => digits
        });
        WatchUi.pushView(picker, new NumberPickerDelegate(item, key, minV, maxV, unit), WatchUi.SLIDE_LEFT);
    }
}

class NumberPickerDelegate extends WatchUi.PickerDelegate {

    var mItem;
    var mKey;
    var mMin;
    var mMax;
    var mUnit;

    function initialize(item, key, minV, maxV, unit) {
        PickerDelegate.initialize();
        mItem = item;
        mKey = key;
        mMin = minV;
        mMax = maxV;
        mUnit = unit;
    }

    function onAccept(values) {
        var v = values[0] * 100 + values[1] * 10 + values[2];
        if (v < mMin) {
            v = mMin;
        } else if (v > mMax) {
            v = mMax;
        }
        writeSetting(mKey, v);
        mItem.setSubLabel(v.toString() + mUnit);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onCancel() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}

// One column of the picker: digits 0..9
class DigitFactory extends WatchUi.PickerFactory {

    function initialize() {
        PickerFactory.initialize();
    }

    function getSize() {
        return 10;
    }

    function getValue(index) {
        return index;
    }

    function getDrawable(index, selected) {
        return new WatchUi.Text({
            :text => index.toString(),
            :color => Graphics.COLOR_WHITE,
            :font => Graphics.FONT_NUMBER_MEDIUM,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER
        });
    }
}
