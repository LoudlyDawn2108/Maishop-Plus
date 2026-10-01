import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../utils/currency_utils.dart';
import '../widgets/money_scanner_dialog.dart';

class CheckoutDialog extends StatefulWidget {
  const CheckoutDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => const CheckoutDialog(),
    );
  }

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  final TextEditingController _paidController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final cart = context.read<CartProvider>();
    if (cart.customerPaid > 0) {
      _paidController.text = cart.customerPaid.toString();
    }
  }

  @override
  void dispose() {
    _paidController.dispose();
    super.dispose();
  }

  void _onPaidChanged(String val, CartProvider cart) {
    final amount = CurrencyUtils.parseVND(val);
    cart.setCustomerPaid(amount);
  }

  void _setExactPaid(CartProvider cart) {
    cart.setCustomerPaid(cart.totalAmount);
    _paidController.text = cart.totalAmount.toString();
  }

  void _addPaid(int amount, CartProvider cart) {
    cart.addCustomerPaid(amount);
    _paidController.text = cart.customerPaid.toString();
  }

  void _openMoneyScanner(CartProvider cart) {
    MoneyScannerDialog.show(context, (detectedDenom) {
      _addPaid(detectedDenom, cart);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cart = context.watch<CartProvider>();
    final total = cart.totalAmount;
    final paid = cart.customerPaid;
    final change = cart.changeAmount;
    final isEnough = cart.isCustomerPaidEnough;

    final suggestedPayments = CurrencyUtils.getSuggestedPayments(total);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thanh kéo drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Thanh toán hóa đơn',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Thẻ hiển thị tổng tiền cần thu
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TỔNG TIỀN:',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      CurrencyUtils.formatVND(total),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Chọn phương thức thanh toán
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      avatar: const Icon(Icons.payments_rounded, size: 18),
                      label: const Text('Tiền mặt'),
                      selected: cart.paymentMethod == 'TIEN_MAT',
                      onSelected: (val) {
                        if (val) cart.setPaymentMethod('TIEN_MAT');
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      avatar: const Icon(Icons.qr_code_rounded, size: 18),
                      label: const Text('Chuyển khoản'),
                      selected: cart.paymentMethod == 'CHUYEN_KHOAN',
                      onSelected: (val) {
                        if (val) {
                          cart.setPaymentMethod('CHUYEN_KHOAN');
                          _setExactPaid(cart);
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (cart.paymentMethod == 'TIEN_MAT') ...[
                // Ô nhập tiền khách đưa
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _paidController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'Tiền khách đưa (VNĐ)',
                          prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
                          suffixText: '₫',
                          suffixIcon: _paidController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    _paidController.clear();
                                    cart.setCustomerPaid(0);
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) => _onPaidChanged(val, cart),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Nút quét tiền polymer
                    IconButton.filledTonal(
                      tooltip: 'Quét tiền Polymer bằng Camera',
                      padding: const EdgeInsets.all(16),
                      icon: const Icon(Icons.document_scanner_rounded),
                      onPressed: () => _openMoneyScanner(cart),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Các nút gợi ý tiền nhanh
                const Text(
                  'Gợi ý tiền khách đưa:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.done_all_rounded, size: 16),
                      label: const Text('Đúng tiền'),
                      backgroundColor: colorScheme.secondaryContainer,
                      onPressed: () => _setExactPaid(cart),
                    ),
                    ...suggestedPayments.where((amt) => amt != total).map((amt) {
                      return ActionChip(
                        avatar: const Icon(Icons.payments_outlined, size: 16),
                        label: Text(CurrencyUtils.formatVND(amt)),
                        onPressed: () {
                          cart.setCustomerPaid(amt);
                          _paidController.text = amt.toString();
                        },
                      );
                    }),
                  ],
                ),

                const SizedBox(height: 8),

                // Hàng chip cộng nhanh mệnh giá (+10k, +20k, +50k...)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [10000, 20000, 50000, 100000, 200000, 500000].map((delta) {
                    final label = '+${delta ~/ 1000}k';
                    return FilterChip(
                      label: Text(label),
                      selected: false,
                      onSelected: (_) => _addPaid(delta, cart),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Thẻ hiển thị TIỀN THỐI LẠI
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isEnough
                        ? Colors.green.withOpacity(0.12)
                        : Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isEnough ? Colors.green : Colors.orange,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEnough ? 'TIỀN THỐI LẠI:' : 'CÒN THIẾU:',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isEnough ? Colors.green.shade800 : Colors.orange.shade900,
                            ),
                          ),
                          Text(
                            CurrencyUtils.formatVND(change.abs()),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: isEnough ? Colors.green.shade800 : Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                      if (isEnough && change > 0) ...[
                        const Divider(height: 16),
                        Row(
                          children: [
                            Icon(Icons.lightbulb_outline_rounded, size: 16, color: Colors.green.shade800),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Gợi ý trả: ${CurrencyUtils.formatChangeBreakdown(change)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Nút HOÀN TẤT ĐƠN HÀNG
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: (paid < total && cart.paymentMethod == 'TIEN_MAT')
                    ? null
                    : () async {
                        try {
                          await cart.completeOrder();
                          if (context.mounted) {
                            Navigator.of(context).pop(true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('Đã thanh toán và lưu đơn hàng thành công!'),
                                  ],
                                ),
                                backgroundColor: colorScheme.primary,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Lỗi: $e'),
                                backgroundColor: colorScheme.error,
                              ),
                            );
                          }
                        }
                      },
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text(
                  'HOÀN TẤT & LƯU ĐƠN',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
