import 'package:intl/intl.dart';

class CurrencyUtils {
  static final NumberFormat _formatter = NumberFormat('#,###', 'vi_VN');

  /// Định dạng tiền tệ VNĐ (ví dụ: 15.000 ₫)
  static String formatVND(int amount) {
    if (amount == 0) return '0 ₫';
    return '${_formatter.format(amount)} ₫';
  }

  /// Định dạng số không có ký hiệu tiền (ví dụ: 15.000)
  static String formatNumber(int amount) {
    return _formatter.format(amount);
  }

  /// Chuyển chuỗi tiền gõ vào thành số nguyên (bỏ dấu chấm, dấu phẩy, chữ đ)
  static int parseVND(String input) {
    if (input.trim().isEmpty) return 0;
    final cleaned = input.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  /// Bỏ dấu tiếng Việt để phục vụ tìm kiếm không phân biệt dấu
  static String removeDiacritics(String str) {
    var withDiacritics = 'áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđ'
        'ÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬÉÈẺẼẸÊẾỀỂỄỆÍÌỈĨỊÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÚÙỦŨỤƯỨỪỬỮỰÝỲỶỸỴĐ';
    var withoutDiacritics = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
        'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';

    for (int i = 0; i < withDiacritics.length; i++) {
      str = str.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return str.toLowerCase();
  }

  /// Các mệnh giá tiền mặt Việt Nam phổ biến
  static const List<int> vietnameseDenominations = [
    500000,
    200000,
    100000,
    50000,
    20000,
    10000,
    5000,
    2000,
    1000,
  ];

  /// Gợi ý các nút tiền khách có thể đưa dựa trên tổng tiền
  /// Ví dụ đơn 63.000đ -> gợi ý: [63.000đ (đúng tiền), 65.000đ, 70.000đ, 100.000đ, 200.000đ, 500.000đ]
  static List<int> getSuggestedPayments(int totalAmount) {
    if (totalAmount <= 0) return [10000, 20000, 50000, 100000, 200000, 500000];

    final Set<int> suggestions = {totalAmount};

    // Làm tròn lên 5k, 10k, 20k, 50k, 100k
    final roundTargets = [1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000, 500000];
    for (final round in roundTargets) {
      if (totalAmount < round) {
        suggestions.add(round);
      } else {
        int remainder = totalAmount % round;
        if (remainder != 0) {
          int roundedUp = totalAmount + (round - remainder);
          suggestions.add(roundedUp);
        }
      }
    }

    final sorted = suggestions.where((amount) => amount >= totalAmount).toList()..sort();
    return sorted.take(6).toList();
  }

  /// Gợi ý số tờ tiền thối lại tối ưu
  /// Ví dụ: 37.000đ -> {20000: 1, 10000: 1, 5000: 1, 2000: 1}
  static Map<int, int> calculateChangeBreakdown(int changeAmount) {
    final Map<int, int> breakdown = {};
    int remaining = changeAmount;

    for (final denom in vietnameseDenominations) {
      if (remaining >= denom) {
        int count = remaining ~/ denom;
        breakdown[denom] = count;
        remaining %= denom;
      }
    }
    return breakdown;
  }

  /// Chuỗi tóm tắt gợi ý tờ tiền thối (ví dụ: "1 tờ 20k, 1 tờ 10k, 1 tờ 5k, 1 tờ 2k")
  static String formatChangeBreakdown(int changeAmount) {
    if (changeAmount <= 0) return '';
    final breakdown = calculateChangeBreakdown(changeAmount);
    if (breakdown.isEmpty) return '';

    return breakdown.entries.map((e) {
      String denomStr;
      if (e.key >= 1000) {
        denomStr = '${e.key ~/ 1000}k';
      } else {
        denomStr = '${e.key}đ';
      }
      return '${e.value} tờ $denomStr';
    }).join(', ');
  }

  /// Phân tích văn bản nhận diện từ camera ML Kit sang mệnh giá tiền Polymer VNĐ
  static int? extractVndDenominationFromOcr(String ocrText) {
    // Tìm các chuỗi số tương ứng mệnh giá tiền Việt Nam từ lớn đến bé
    final patterns = [
      RegExp(r'(?:^|[^\d])(500)[.\s,]?(000)(?:[^\d]|$)'),
      RegExp(r'(?:^|[^\d])(200)[.\s,]?(000)(?:[^\d]|$)'),
      RegExp(r'(?:^|[^\d])(100)[.\s,]?(000)(?:[^\d]|$)'),
      RegExp(r'(?:^|[^\d])(50)[.\s,]?(000)(?:[^\d]|$)'),
      RegExp(r'(?:^|[^\d])(20)[.\s,]?(000)(?:[^\d]|$)'),
      RegExp(r'(?:^|[^\d])(10)[.\s,]?(000)(?:[^\d]|$)'),
      RegExp(r'(?:^|[^\d])(5)[.\s,]?(000)(?:[^\d]|$)'),
      RegExp(r'(?:^|[^\d])(2)[.\s,]?(000)(?:[^\d]|$)'),
      RegExp(r'(?:^|[^\d])(1)[.\s,]?(000)(?:[^\d]|$)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(ocrText);
      if (match != null) {
        final thousands = match.group(1);
        final zeros = match.group(2);
        if (thousands != null && zeros != null) {
          final val = int.tryParse('$thousands$zeros');
          if (val != null && vietnameseDenominations.contains(val)) {
            return val;
          }
        }
      }
    }

    return null;
  }
}
