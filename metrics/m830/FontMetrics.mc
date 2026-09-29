// System font metrics measured in the Connect IQ simulator (CI calibration
// screen), order XTINY, TINY, SMALL, MEDIUM, LARGE:
// empty pixels above the capitals/digits, and their height.
function fontTopPx(i) {
    return [3,5,5,6,9][i];
}

function fontCapPx(i) {
    return [8,12,13,16,24][i];
}
