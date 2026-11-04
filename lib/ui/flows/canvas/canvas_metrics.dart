/// The fixed geometry of the flow canvas. Nodes are laid out from these
/// numbers alone -- every section and row has a fixed height -- so the wires
/// can find any pin by arithmetic instead of measuring widgets. The node
/// widget must render exactly these heights.
library;

const double nodeWidth = 240;
const double nodeGap = 56;
const double canvasPadding = 24;

const double headerHeight = 44;
const double pathHeight = 24;
const double sectionLabelHeight = 24;
const double rowHeight = 24;
const double sectionGap = 8;
const double emptyResponseHeight = 56;
const double nodeBottomPadding = 8;

/// How far a node's widget reaches past its card on each side, so the pins
/// drawn on the card's edges can be grabbed whole (a widget only receives
/// pointer events inside its own bounds).
const double pinOverhang = 11;

/// The "+ Add step" node at the end of the row.
const double addNodeWidth = 160;
const double addNodeHeight = 56;

/// A node lists at most this many response fields; the rest are in the panel.
const int maxVisibleFields = 8;

const double minZoom = 0.5;
const double maxZoom = 1.5;
const double zoomStep = 0.1;

/// The x of node [index] in the canvas (nodes all start at [canvasPadding] from the top).
double nodeLeft(int index) => canvasPadding + index * (nodeWidth + nodeGap);

/// The height of a node with [inputRows] input rows and [responseRows] rows
/// in its response section (fields, "+N more" and message rows); a node
/// without a response shows the "not sent yet" box instead.
double nodeHeight(int inputRows, int responseRows, {required bool hasResponse}) =>
    headerHeight +
    pathHeight +
    sectionLabelHeight +
    inputRows * rowHeight +
    sectionGap +
    sectionLabelHeight +
    (hasResponse ? responseRows * rowHeight : emptyResponseHeight) +
    nodeBottomPadding;

/// The y of the center of input row [row], from the top of its node.
double inputRowCenterY(int row) => headerHeight + pathHeight + sectionLabelHeight + row * rowHeight + rowHeight / 2;

/// The y of the center of response row [row] of a node with [inputRows] input
/// rows, from the top of the node.
double fieldRowCenterY(int inputRows, int row) =>
    headerHeight +
    pathHeight +
    sectionLabelHeight +
    inputRows * rowHeight +
    sectionGap +
    sectionLabelHeight +
    row * rowHeight +
    rowHeight / 2;
