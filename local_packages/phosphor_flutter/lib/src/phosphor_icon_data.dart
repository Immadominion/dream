library phosphor_flutter;

import 'package:flutter/widgets.dart';

// Patched: Avoid extending/implementing IconData (became final in Flutter 3.27+).
// All icon files now use IconData(...) directly. These typedefs preserve
// backward-compat for any code that references PhosphorIconData as a type.
typedef PhosphorIconData = IconData;
typedef PhosphorFlatIconData = IconData;
typedef PhosphorDuotoneIconData = IconData;
