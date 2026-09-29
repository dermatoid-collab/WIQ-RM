import Toybox.Activity;
import Toybox.Application;
import Toybox.FitContributor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// Time in Coggan power zones (%FTP) + Sweet Spot, Z4 and Z4+ totals.
//
// Time is accumulated from 1 s power while the activity timer is running
// (timer paused / auto-pause = not counted, power sensor dropout = not counted,
// 0 W while coasting = Z1). The highlighted "current zone" uses the smoothed
// power shown in the footer so it does not flicker.
class PowerZonesView extends WatchUi.DataField {

    const NUM_ZONES = 7;
    const MAX_AVG = 10;
    const STRIPE_W = 6;

    // Z1..Z7, same palette as the reference field
    var mZoneColors = [0xAAFFFF, 0x00AAFF, 0x00FF00, 0xFFFF00, 0xFFAA00, 0xFF55FF, 0xFF0000];
    const COLOR_SS = 0xFFAA00;
    const COLOR_Z4 = 0xFFFF00;
    const COLOR_Z4PLUS = 0xFF5500;

    // Settings
    var mFtp = 250;
    var mZoneMaxPct = [55, 75, 90, 105, 120, 150];
    var mZoneMaxW = new [6];
    // Sweet Spot fixed at 84-97 %FTP, limits included
    const SS_LOW_PCT = 84;
    const SS_HIGH_PCT = 97;
    var mSsLowW = 0;
    var mSsHighW = 0;
    var mAvgN = 3;
    var mRangePct = false;
    var mLastFieldPct = false;

    // Accumulators (milliseconds)
    var mZoneMs = new [7];
    var mSsMs = 0;
    var mTotalMs = 0;
    var mLastTimer = null;

    // Live values
    var mSamples = new [10];
    var mSampleCount = 0;
    var mSampleIdx = 0;
    var mDispPower = null;
    var mCurZone = -1;
    var mInSs = false;
    var mAvgPower = null;

    // Normalized Power: 30 s rolling average, 4th power, mean, 4th root
    var mNpBuf = new [30];
    var mNpIdx = 0;
    var mNpCount = 0;
    var mNpRollSum = 0;
    var mNpSum4 = 0.0d;
    var mNpN = 0;
    var mNp = null;

    // FIT session fields (minutes)
    var mFitSs = null;
    var mFitZ4 = null;
    var mFitZ4Plus = null;

    // UI
    var mFg = Graphics.COLOR_BLACK;
    var mBg = Graphics.COLOR_WHITE;
    var mDark = false;
    var mFull = false;
    var mShowTimes = false; // bottom strip: false = NP/Avg/Pwr 3s, true = SS/Z4/Z4+
    var mNumFonts = [Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD];
    var mFonts = [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY];

    var mStrNp;
    var mStrAvg;
    var mStrPower;
    var mStrFtp;
    var mStrSs;
    var mStrSsShort;
    var mStrZ4;
    var mStrZ4Plus;

    function initialize() {
        DataField.initialize();

        mStrNp = WatchUi.loadResource(Rez.Strings.LblNp);
        mStrAvg = WatchUi.loadResource(Rez.Strings.LblAvg);
        mStrPower = WatchUi.loadResource(Rez.Strings.LblPower);
        mStrFtp = WatchUi.loadResource(Rez.Strings.LblFtp);
        mStrSs = WatchUi.loadResource(Rez.Strings.LblSs);
        mStrSsShort = WatchUi.loadResource(Rez.Strings.LblSsShort);
        mStrZ4 = WatchUi.loadResource(Rez.Strings.LblZ4);
        mStrZ4Plus = WatchUi.loadResource(Rez.Strings.LblZ4Plus);

        resetTotals();
        loadSettings();

        mFitSs = createField("sweet_spot_min", 0, FitContributor.DATA_TYPE_FLOAT,
            {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "min"});
        mFitZ4 = createField("z4_min", 1, FitContributor.DATA_TYPE_FLOAT,
            {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "min"});
        mFitZ4Plus = createField("z4plus_min", 2, FitContributor.DATA_TYPE_FLOAT,
            {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "min"});
        mFitSs.setData(0.0);
        mFitZ4.setData(0.0);
        mFitZ4Plus.setData(0.0);
    }

    // ---------------------------------------------------------------- settings

    function readNum(key, def) {
        var v = null;
        try {
            v = Application.Properties.getValue(key);
        } catch (e) {
            v = null;
        }
        if (v instanceof Number) {
            return v;
        }
        if (v instanceof Float || v instanceof Double || v instanceof Long) {
            return v.toNumber();
        }
        if (v instanceof String) {
            var n = v.toNumber();
            if (n != null) {
                return n;
            }
        }
        return def;
    }

    function loadSettings() {
        mFtp = readNum("ftp", 295);
        if (mFtp < 50) {
            mFtp = 50;
        }
        var keys = ["z1Max", "z2Max", "z3Max", "z4Max", "z5Max", "z6Max"];
        var defs = [55, 75, 90, 105, 120, 150];
        var prev = 0;
        for (var i = 0; i < 6; i++) {
            var p = readNum(keys[i], defs[i]);
            if (p <= prev) {
                p = prev + 1; // keep limits strictly increasing
            }
            mZoneMaxPct[i] = p;
            mZoneMaxW[i] = (mFtp * p) / 100;
            prev = p;
        }
        mSsLowW = (mFtp * SS_LOW_PCT + 99) / 100;
        mSsHighW = (mFtp * SS_HIGH_PCT) / 100;

        mAvgN = readNum("powerAvg", 3);
        if (mAvgN < 1) {
            mAvgN = 1;
        } else if (mAvgN > MAX_AVG) {
            mAvgN = MAX_AVG;
        }
        mSampleCount = 0;
        mSampleIdx = 0;
        mRangePct = readNum("rangeUnits", 0) == 1;
        mLastFieldPct = readNum("lastField", 0) == 1;
    }

    // ------------------------------------------------------------------ logic

    function resetTotals() {
        for (var i = 0; i < NUM_ZONES; i++) {
            mZoneMs[i] = 0;
        }
        mSsMs = 0;
        mTotalMs = 0;
        mLastTimer = null;
        mNpIdx = 0;
        mNpCount = 0;
        mNpRollSum = 0;
        mNpSum4 = 0.0d;
        mNpN = 0;
        mNp = null;
    }

    function onTimerReset() {
        resetTotals();
        updateFit();
    }

    function zoneOf(w) {
        for (var i = 0; i < 6; i++) {
            if (w <= mZoneMaxW[i]) {
                return i;
            }
        }
        return 6;
    }

    function isSs(w) {
        return w >= mSsLowW && w <= mSsHighW;
    }

    function compute(info) {
        var p = null;
        if (info has :currentPower) {
            p = info.currentPower;
        }

        // Smoothed power for display / current zone
        if (p != null) {
            mSamples[mSampleIdx] = p;
            mSampleIdx = (mSampleIdx + 1) % mAvgN;
            if (mSampleCount < mAvgN) {
                mSampleCount++;
            }
            var sum = 0;
            for (var i = 0; i < mSampleCount; i++) {
                sum += mSamples[i];
            }
            mDispPower = (sum.toFloat() / mSampleCount + 0.5).toNumber();
            mCurZone = zoneOf(mDispPower);
            mInSs = isSs(mDispPower);
        } else {
            mSampleCount = 0;
            mSampleIdx = 0;
            mDispPower = null;
            mCurZone = -1;
            mInSs = false;
        }

        mAvgPower = (info has :averagePower) ? info.averagePower : null;

        // Time accumulation driven by the activity timer (stops on pause)
        var t = info.timerTime;
        if (t == null) {
            return;
        }
        if (mLastTimer != null) {
            var dt = t - mLastTimer;
            if (dt < 0) {
                resetTotals();
            } else if (dt > 0 && dt <= 5000 && p != null) {
                var z = zoneOf(p);
                mZoneMs[z] += dt;
                mTotalMs += dt;
                if (isSs(p)) {
                    mSsMs += dt;
                }
                addNpSample(p);
                updateFit();
            }
        }
        mLastTimer = t;
    }

    // Called once per timer second with 1 s power
    function addNpSample(p) {
        if (mNpCount == 30) {
            mNpRollSum -= mNpBuf[mNpIdx];
        } else {
            mNpCount++;
        }
        mNpBuf[mNpIdx] = p;
        mNpRollSum += p;
        mNpIdx = (mNpIdx + 1) % 30;
        if (mNpCount == 30) {
            var a = mNpRollSum.toDouble() / 30.0d;
            mNpSum4 += a * a * a * a;
            mNpN++;
            mNp = (Math.pow(mNpSum4 / mNpN, 0.25) + 0.5).toNumber();
        }
    }

    function z4PlusMs() {
        var s = 0;
        for (var i = 3; i < NUM_ZONES; i++) {
            s += mZoneMs[i];
        }
        return s;
    }

    function updateFit() {
        if (mFitSs == null) {
            return;
        }
        mFitSs.setData(mSsMs / 60000.0);
        mFitZ4.setData(mZoneMs[3] / 60000.0);
        mFitZ4Plus.setData(z4PlusMs() / 60000.0);
    }

    // -------------------------------------------------------------- formatting

    function fmtTime(ms) {
        var s = ms / 1000;
        var h = s / 3600;
        var m = (s % 3600) / 60;
        s = s % 60;
        return h.format("%d") + ":" + m.format("%02d") + ":" + s.format("%02d");
    }

    function rangeText(z) {
        var a = mRangePct ? mZoneMaxPct : mZoneMaxW;
        var u = mRangePct ? "%" : "W";
        if (z == 0) {
            return "0 - " + a[0].toString() + u;
        } else if (z == 6) {
            return "> " + a[5].toString() + u;
        }
        return (a[z - 1] + 1).toString() + " - " + a[z].toString() + u;
    }

    // Digits and ':' only: safe to draw with the large number fonts
    function isNumeric(text) {
        var chars = text.toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            var c = chars[i].toNumber();
            if (!((c >= 48 && c <= 57) || c == 58)) {
                return false;
            }
        }
        return chars.size() > 0;
    }

    // Largest font whose height fits maxH (and text fits maxW when given)
    function pickFont(dc, text, maxW, maxH) {
        for (var i = 0; i < mFonts.size(); i++) {
            var f = mFonts[i];
            if (dc.getFontHeight(f) <= maxH &&
                (text == null || dc.getTextWidthInPixels(text, f) <= maxW)) {
                return f;
            }
        }
        return Graphics.FONT_XTINY;
    }

    // ------------------------------------------------------------------ drawing

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        mBg = getBackgroundColor();
        mDark = (mBg == Graphics.COLOR_BLACK);
        mFg = mDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        dc.setColor(mFg, mBg);
        dc.clear();

        mFull = (h >= 240);
        if (mFull) {
            // Full page: 7 zone rows + one strip of 3 cells (tap toggles the set)
            var stripH = (h * 14) / 100;
            var rowH = (h - stripH) / NUM_ZONES;
            var zonesH = rowH * NUM_ZONES;
            for (var i = 0; i < NUM_ZONES; i++) {
                drawZoneRow(dc, NUM_ZONES - 1 - i, 0, i * rowH, w, rowH);
            }
            if (mShowTimes) {
                drawSummary(dc, 0, zonesH, w, h - zonesH);
            } else {
                drawFooter(dc, 0, zonesH, w, h - zonesH);
            }
        } else if (h >= 90) {
            var half = h / 2;
            drawSummary(dc, 0, 0, w, half);
            drawFooter(dc, 0, half, w, h - half);
        } else {
            drawSummary(dc, 0, 0, w, h);
        }
    }

    // Called by PowerZonesDelegate on a tap inside the field
    function onFieldTap() {
        if (!mFull) {
            return false;
        }
        mShowTimes = !mShowTimes;
        WatchUi.requestUpdate();
        return true;
    }

    function drawZoneRow(dc, z, x, y, w, rh) {
        var col = mZoneColors[z];
        var ms = mZoneMs[z];
        var frac = mTotalMs > 0 ? ms.toFloat() / mTotalMs : 0.0;
        var inner = w - STRIPE_W;

        dc.setColor(col, col);
        dc.fillRectangle(x, y, STRIPE_W, rh);
        var barW = (inner * frac).toNumber();
        if (barW > 0) {
            if (mDark) {
                // thin bar keeps white text readable on black
                dc.fillRectangle(x + STRIPE_W, y + rh - 5, barW, 4);
            } else {
                dc.fillRectangle(x + STRIPE_W, y + 1, barW, rh - 2);
            }
        }

        var label = "Z" + (z + 1);
        var timeStr = ms > 0 ? fmtTime(ms) : "";
        var pctStr = mTotalMs > 0 ? (frac * 100 + 0.5).toNumber().toString() + "%" : "";
        var range = rangeText(z);
        var tx = x + STRIPE_W + 6;
        var right = x + w - 6;

        // Two lines, like the reference field:
        //   "Z3 0:12:34"          (large)
        //   "224 - 268W      21%" (small)
        // Garmin fonts carry empty space above the glyphs, so the large line
        // may use ~20% more height than what is left above the small line.
        var sf = Graphics.FONT_XTINY;
        var sh = dc.getFontHeight(sf);
        var y2 = y + rh - sh;
        var f = Graphics.FONT_XTINY;
        for (var i = 0; i < mFonts.size(); i++) {
            var fh = dc.getFontHeight(mFonts[i]);
            if ((fh * 80) / 100 <= rh - sh + 2 &&
                dc.getTextWidthInPixels(label + " 0:00:00", mFonts[i]) <= right - tx) {
                f = mFonts[i];
                break;
            }
        }
        var fh1 = dc.getFontHeight(f);
        var y1 = y2 - (fh1 * 80) / 100;
        if (y1 < y - fh1 / 5) {
            y1 = y - fh1 / 5;
        }

        dc.setColor(mFg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(tx, y1, f, timeStr.length() > 0 ? label + " " + timeStr : label, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(tx, y2, sf, range, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(right, y2, sf, pctStr, Graphics.TEXT_JUSTIFY_RIGHT);

        // Before the first second of data, show which build is installed
        if (z == 6 && mTotalMs == 0) {
            dc.drawText(right, y + 2, sf, "build " + BUILD_NUMBER, Graphics.TEXT_JUSTIFY_RIGHT);
        }

        if (z == mCurZone) {
            drawCurrentMarker(dc, x, y, w, rh);
        }
    }

    function drawCurrentMarker(dc, x, y, w, rh) {
        dc.setColor(mFg, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRectangle(x + 1, y + 1, w - 2, rh - 1);
        dc.setPenWidth(1);
        var cy = y + rh / 2;
        var a = rh / 4;
        if (a > 8) {
            a = 8;
        }
        dc.fillPolygon([[x + 1, cy - a], [x + 1 + a, cy], [x + 1, cy + a]]);
        dc.fillPolygon([[x + w - 2, cy - a], [x + w - 2 - a, cy], [x + w - 2, cy + a]]);
    }

    function drawSummary(dc, x, y, w, h) {
        var cw = w / 3;
        var ssLabel = (cw > 110) ? mStrSs : mStrSsShort;
        drawCell(dc, x, y, cw, h, ssLabel, fmtTime(mSsMs), mInSs ? COLOR_SS : null);
        drawCell(dc, x + cw, y, cw, h, mStrZ4, fmtTime(mZoneMs[3]), mCurZone == 3 ? COLOR_Z4 : null);
        drawCell(dc, x + 2 * cw, y, w - 2 * cw, h, mStrZ4Plus, fmtTime(z4PlusMs()), mCurZone >= 3 ? COLOR_Z4PLUS : null);
    }

    function drawFooter(dc, x, y, w, h) {
        var cw = w / 3;
        drawCell(dc, x, y, cw, h, mStrNp, mNp != null ? mNp.toString() : "--", null);
        drawCell(dc, x + cw, y, cw, h, mStrAvg, mAvgPower != null ? mAvgPower.toString() : "--", null);

        var label = (mLastFieldPct ? mStrFtp : mStrPower) + " " + mAvgN.toString() + "s";
        var val = "--";
        if (mDispPower != null) {
            val = mLastFieldPct
                ? ((mDispPower * 100.0 / mFtp) + 0.5).toNumber().toString() + "%"
                : mDispPower.toString();
        }
        drawCell(dc, x + 2 * cw, y, w - 2 * cw, h, label, val, mCurZone >= 0 ? mZoneColors[mCurZone] : null);
    }

    function drawCell(dc, x, y, cw, ch, label, value, hl) {
        var fg = mFg;
        if (hl != null) {
            dc.setColor(hl, hl);
            dc.fillRectangle(x, y, cw, ch);
            fg = Graphics.COLOR_BLACK;
        }
        // Label: largest of SMALL/TINY/XTINY that uses at most ~40% of the cell
        var lf = Graphics.FONT_XTINY;
        var labelFonts = [Graphics.FONT_SMALL, Graphics.FONT_TINY];
        for (var i = 0; i < labelFonts.size(); i++) {
            if (dc.getFontHeight(labelFonts[i]) * 10 <= ch * 4 &&
                dc.getTextWidthInPixels(label, labelFonts[i]) <= cw - 4) {
                lf = labelFonts[i];
                break;
            }
        }
        var lh = dc.getFontHeight(lf);
        var cx = x + cw / 2;
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, lf, label, Graphics.TEXT_JUSTIFY_CENTER);

        var avail = ch - lh + 4;
        var vf = null;
        if (isNumeric(value)) {
            for (var k = 0; k < mNumFonts.size(); k++) {
                var nf = mNumFonts[k];
                if (dc.getFontHeight(nf) <= avail && dc.getTextWidthInPixels(value, nf) <= cw - 4) {
                    vf = nf;
                    break;
                }
            }
        }
        if (vf == null) {
            vf = pickFont(dc, value, cw - 4, avail);
        }
        var vh = dc.getFontHeight(vf);
        var vy = y + lh - 2 + (avail - vh) / 2;
        dc.drawText(cx, vy, vf, value, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(mFg, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, cw, ch);
    }
}
