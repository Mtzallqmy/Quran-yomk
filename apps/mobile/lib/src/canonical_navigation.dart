// Generated from pinned legacy2092 navigation and official KFGQPC canonical2.
// Navigation metadata only; never a second Quran-text source.
const legacyQuranPageCorrections = <String, List<int>>{
  '5:77': [121, 120],
  '5:83': [122, 121],
  '5:90': [123, 122],
  '6:131': [144, 145],
  '55:17': [532, 531],
  '55:18': [532, 531],
  '55:41': [533, 532],
  '55:68': [534, 533],
  '55:69': [534, 533],
  '68:16': [565, 564],
  '69:35': [568, 567],
  '70:40': [570, 569],
  '74:18': [576, 575],
  '79:16': [584, 583],
  '80:41': [585, 586],
  '80:42': [585, 586],
  '83:5': [587, 588],
  '83:6': [587, 588],
  '83:34': [588, 589],
  '84:25': [589, 590],
  '87:11': [591, 592],
  '87:12': [591, 592],
  '87:13': [591, 592],
  '87:14': [591, 592],
  '87:15': [591, 592],
  '88:23': [592, 593],
  '88:24': [592, 593],
  '88:25': [592, 593],
  '88:26': [592, 593],
  '89:23': [593, 594],
  '90:19': [594, 595],
  '90:20': [594, 595],
  '92:10': [595, 596],
  '92:11': [595, 596],
  '92:12': [595, 596],
  '92:13': [595, 596],
  '92:14': [595, 596],
  '94:3': [596, 597],
  '94:4': [596, 597],
  '94:5': [596, 597],
  '94:6': [596, 597],
  '94:7': [596, 597],
  '94:8': [596, 597],
  '96:13': [597, 598],
  '96:14': [597, 598],
  '96:15': [597, 598],
  '96:16': [597, 598],
  '96:17': [597, 598],
  '96:18': [597, 598],
  '96:19': [597, 598],
  '98:6': [598, 599],
  '98:7': [598, 599],
  '100:6': [599, 600],
  '100:7': [599, 600],
  '100:8': [599, 600],
  '100:9': [599, 600],
};

Map<String, dynamic> reconcileLegacyQuranPage(Map<String, dynamic> raw) {
  final correction = legacyQuranPageCorrections[raw['verse_key']];
  if (correction == null) return raw;
  final changeNumber = raw['mode'] == 'page' && raw['number'] == correction[0];
  final changePage =
      raw['page_number'] == correction[0] ||
      (raw['page_number'] == null && changeNumber);
  if (!changeNumber && !changePage) return raw;
  return {
    ...raw,
    if (changeNumber) 'number': correction[1],
    if (changePage) 'page_number': correction[1],
  };
}
