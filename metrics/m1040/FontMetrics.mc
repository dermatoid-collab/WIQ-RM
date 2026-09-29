// System font metrics measured in the Connect IQ simulator (CI calibration
// screen), order XTINY, TINY, SMALL, MEDIUM, LARGE:
// empty pixels above the capitals/digits, and their height.
function fontTopPx(i) {
    return [0,0,1,1,1][i];
}

function fontCapPx(i) {
    return [9,12,13,15,25][i];
}
