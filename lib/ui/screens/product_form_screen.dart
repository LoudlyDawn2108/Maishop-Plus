import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/inventory_provider.dart';
import '../../services/product_lookup_service.dart';
import '../../utils/currency_utils.dart';
import '../widgets/barcode_scanner_sheet.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? productToEdit;
  final String? initialBarcode;

  const ProductFormScreen({
    super.key,
    this.productToEdit,
    this.initialBarcode,
  });

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _barcodeController;
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _costPriceController;
  late TextEditingController _stockController;
  late TextEditingController _categoryController;

  String _selectedUnit = 'Cái';
  bool _isLookingUp = false;
  String? _lookupSuccessNotice;
  String? _lookupOriginalName;
  bool _wasTranslated = false;
  Timer? _debounceTimer;

  final FocusNode _priceFocusNode = FocusNode();

  static const List<String> _commonUnits = [
    'Cái',
    'Gói',
    'Lon',
    'Chai',
    'Hộp',
    'Kg',
    'Túi',
    'Thùng',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;

    _barcodeController = TextEditingController(text: p?.barcode ?? widget.initialBarcode ?? '');
    _nameController = TextEditingController(text: p?.name ?? '');
    _priceController = TextEditingController(text: p != null ? p.price.toString() : '');
    _costPriceController = TextEditingController(text: p?.costPrice != null ? p!.costPrice.toString() : '');
    _stockController = TextEditingController(text: p != null ? p.stock.toString() : '10');
    _categoryController = TextEditingController(text: p?.category ?? 'Chung');
    _selectedUnit = p?.unit ?? 'Cái';

    // Nếu tạo mới và đã có mã vạch ban đầu, tự động tra cứu tên
    if (widget.productToEdit == null && _barcodeController.text.isNotEmpty) {
      _lookupOnlineName(_barcodeController.text);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _barcodeController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  void _onBarcodeChanged(String val) {
    _debounceTimer?.cancel();
    final clean = val.trim();
    if (widget.productToEdit == null && clean.length >= 8) {
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _lookupOnlineName(clean);
      });
    }
  }

  /// Tra cứu tên sản phẩm từ mã vạch qua các nguồn mở & tự động dịch sang tiếng Việt
  Future<void> _lookupOnlineName(String barcode) async {
    if (barcode.trim().isEmpty) return;

    setState(() {
      _isLookingUp = true;
      _lookupSuccessNotice = null;
      _lookupOriginalName = null;
      _wasTranslated = false;
    });

    final result = await ProductLookupService.lookupProduct(barcode);

    if (mounted) {
      setState(() {
        _isLookingUp = false;
        if (result != null && result.productName.isNotEmpty) {
          _nameController.text = result.productName;
          _lookupOriginalName = result.originalName;
          _wasTranslated = result.wasTranslated;
          if (result.wasTranslated && result.originalName != null) {
            _lookupSuccessNotice = 'Tự động dịch sang Tiếng Việt (${result.source})';
          } else {
            _lookupSuccessNotice = 'Đã tìm thấy từ ${result.source}';
          }
          // Tự động focus vào ô giá bán để gõ giá ngay
          _priceFocusNode.requestFocus();
        }
      });
    }
  }

  /// Mở camera quét mã vạch chuyên dụng (có khung chữ nhật, chạm lấy nét, zoom mã nhỏ)
  Future<void> _openBarcodeScanner() async {
    final code = await BarcodeScannerSheet.show(
      context,
      title: 'Quét mã vạch đăng ký',
      hintText: 'Căn mã vạch vào khung chữ nhật • Chạm lấy nét • Chọn 2x nếu mã bé',
    );

    if (code != null && code.isNotEmpty) {
      setState(() {
        _barcodeController.text = code;
      });
      _lookupOnlineName(code);
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final barcode = _barcodeController.text.trim();
    final name = _nameController.text.trim();
    final price = CurrencyUtils.parseVND(_priceController.text);
    final costPrice = _costPriceController.text.trim().isNotEmpty
        ? CurrencyUtils.parseVND(_costPriceController.text)
        : null;
    final stock = int.tryParse(_stockController.text.trim()) ?? 0;
    final category = _categoryController.text.trim().isEmpty ? 'Chung' : _categoryController.text.trim();

    final product = Product(
      barcode: barcode,
      name: name,
      price: price,
      costPrice: costPrice,
      unit: _selectedUnit,
      stock: stock,
      category: category,
      createdAt: widget.productToEdit?.createdAt,
    );

    final provider = context.read<InventoryProvider>();
    bool success;

    if (widget.productToEdit != null) {
      success = await provider.updateProduct(product);
    } else {
      success = await provider.addProduct(product);
    }

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(widget.productToEdit != null
                    ? 'Đã cập nhật sản phẩm thành công'
                    : 'Đã lưu sản phẩm vào kho thành công'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Có lỗi xảy ra khi lưu sản phẩm'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = widget.productToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Chỉnh sửa sản phẩm' : 'Đăng ký sản phẩm mới'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _saveProduct,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Lưu'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mã vạch
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _barcodeController,
                      readOnly: isEditing,
                      textInputAction: TextInputAction.search,
                      onFieldSubmitted: (val) {
                        _debounceTimer?.cancel();
                        if (!isEditing && val.trim().isNotEmpty) {
                          _lookupOnlineName(val.trim());
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Mã vạch (Barcode) *',
                        hintText: 'Quét hoặc nhập mã',
                        prefixIcon: const Icon(Icons.qr_code_2_rounded),
                        suffixIcon: _isLookingUp
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : (!isEditing
                                ? IconButton(
                                    icon: const Icon(Icons.search_rounded),
                                    tooltip: 'Tra cứu thông tin mã vạch',
                                    onPressed: () {
                                      _debounceTimer?.cancel();
                                      _lookupOnlineName(_barcodeController.text.trim());
                                    },
                                  )
                                : null),
                      ),
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'Vui lòng nhập hoặc quét mã vạch' : null,
                      onChanged: _onBarcodeChanged,
                    ),
                  ),
                  if (!isEditing) ...[
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _openBarcodeScanner,
                      tooltip: 'Mở camera quét mã',
                      padding: const EdgeInsets.all(16),
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                    ),
                  ],
                ],
              ),

              if (_lookupSuccessNotice != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 16, color: colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      _lookupSuccessNotice!,
                      style: TextStyle(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Tên sản phẩm
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên sản phẩm *',
                  hintText: 'Ví dụ: Dầu gội Dove dưỡng ẩm',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Vui lòng nhập tên sản phẩm' : null,
              ),

              if (_wasTranslated && _lookupOriginalName != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.translate_rounded, size: 16, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Tên gốc: $_lookupOriginalName',
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          setState(() {
                            _nameController.text = _lookupOriginalName!;
                          });
                        },
                        child: const Text('Dùng tên gốc', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Giá bán & Giá vốn
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      focusNode: _priceFocusNode,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Giá bán (VNĐ) *',
                        hintText: '10000',
                        prefixIcon: Icon(Icons.payments_rounded),
                        suffixText: '₫',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Nhập giá bán';
                        final num = CurrencyUtils.parseVND(val);
                        if (num <= 0) return 'Giá phải > 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Giá vốn (tùy chọn)',
                        hintText: '8000',
                        prefixIcon: Icon(Icons.price_change_outlined),
                        suffixText: '₫',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Tồn kho & Phân loại
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Số lượng tồn kho',
                        hintText: '0',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Phân loại / Nhóm',
                        hintText: 'Bánh kẹo, Gia vị...',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Đơn vị tính
              const Text(
                'Đơn vị tính:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _commonUnits.map((u) {
                  final isSelected = _selectedUnit == u;
                  return ChoiceChip(
                    label: Text(u),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedUnit = u;
                        });
                      }
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),

              FilledButton.icon(
                onPressed: _saveProduct,
                icon: const Icon(Icons.check_circle_rounded),
                label: Text(
                  isEditing ? 'CẬP NHẬT SẢN PHẨM' : 'LƯU VÀO KHO HÀNG',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
