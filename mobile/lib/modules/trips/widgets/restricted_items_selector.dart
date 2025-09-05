import 'package:flutter/material.dart';
import '../services/trip_service.dart';

class RestrictedItemsSelector extends StatefulWidget {
  final List<String> selectedCategories;
  final List<String> selectedItems;
  final Function(List<String> categories, List<String> items) onSelectionChanged;

  const RestrictedItemsSelector({
    super.key,
    required this.selectedCategories,
    required this.selectedItems,
    required this.onSelectionChanged,
  });

  @override
  State<RestrictedItemsSelector> createState() => _RestrictedItemsSelectorState();
}

class _RestrictedItemsSelectorState extends State<RestrictedItemsSelector> {
  late List<String> _selectedCategories;
  late List<String> _selectedItems;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedCategories = List.from(widget.selectedCategories);
    _selectedItems = List.from(widget.selectedItems);
    
    // Auto-déduire les catégories des items déjà sélectionnés
    _deduceCategoriesFromItems();
  }
  
  void _deduceCategoriesFromItems() {
    for (String item in _selectedItems) {
      for (String category in RestrictedItemsData.categories) {
        final categoryItems = RestrictedItemsData.itemsByCategory[category] ?? [];
        if (categoryItems.contains(item) && !_selectedCategories.contains(category)) {
          _selectedCategories.add(category);
        }
      }
    }
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
        // Remove all items from this category
        final categoryItems = RestrictedItemsData.itemsByCategory[category] ?? [];
        _selectedItems.removeWhere((item) => categoryItems.contains(item));
      } else {
        _selectedCategories.add(category);
      }
    });
    _notifyChange();
  }

  void _toggleItem(String item) {
    setState(() {
      if (_selectedItems.contains(item)) {
        _selectedItems.remove(item);
        // Supprimer la catégorie si plus aucun item de cette catégorie n'est sélectionné
        _removeUnusedCategories();
      } else {
        _selectedItems.add(item);
        // Ajouter automatiquement la catégorie correspondante
        _addCategoryForItem(item);
      }
    });
    _notifyChange();
  }
  
  void _addCategoryForItem(String item) {
    for (String category in RestrictedItemsData.categories) {
      final categoryItems = RestrictedItemsData.itemsByCategory[category] ?? [];
      if (categoryItems.contains(item) && !_selectedCategories.contains(category)) {
        _selectedCategories.add(category);
        break;
      }
    }
  }
  
  void _removeUnusedCategories() {
    _selectedCategories.removeWhere((category) {
      final categoryItems = RestrictedItemsData.itemsByCategory[category] ?? [];
      // Garder la catégorie seulement s'il y a encore des items sélectionnés de cette catégorie
      return !categoryItems.any((item) => _selectedItems.contains(item));
    });
  }

  void _notifyChange() {
    widget.onSelectionChanged(_selectedCategories, _selectedItems);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        TextField(
          decoration: const InputDecoration(
            hintText: 'Rechercher un objet...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
        ),
        
        const SizedBox(height: 16),
        
        // Quick selection buttons
        _buildQuickSelectionButtons(),
        
        const SizedBox(height: 16),
        
        // Categories and items
        SizedBox(
          height: 400, // Fixed height to avoid overflow issues
          child: _searchQuery.isEmpty
              ? _buildCategoriesView()
              : _buildSearchResultsView(),
        ),
        
        // Selection summary
        if (_selectedCategories.isNotEmpty || _selectedItems.isNotEmpty)
          _buildSelectionSummary(),
      ],
    );
  }

  Widget _buildQuickSelectionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _selectCommonRestrictions,
            icon: const Icon(Icons.flash_on, size: 20),
            label: const Text('Restrictions courantes'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _clearAll,
            icon: const Icon(Icons.clear_all, size: 20),
            label: const Text('Tout effacer'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesView() {
    return ListView.builder(
      itemCount: RestrictedItemsData.categories.length,
      itemBuilder: (context, index) {
        final category = RestrictedItemsData.categories[index];
        final items = RestrictedItemsData.itemsByCategory[category] ?? [];
        final isCategorySelected = _selectedCategories.contains(category);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: Checkbox(
              value: isCategorySelected,
              onChanged: (value) => _toggleCategory(category),
            ),
            title: Text(
              category,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isCategorySelected ? Theme.of(context).primaryColor : null,
              ),
            ),
            subtitle: Text('${items.length} objets'),
            children: items.map((item) {
              final isItemSelected = _selectedItems.contains(item);
              return ListTile(
                dense: true,
                leading: const SizedBox(width: 24),
                title: Row(
                  children: [
                    Checkbox(
                      value: isItemSelected,
                      onChanged: (value) => _toggleItem(item),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSearchResultsView() {
    final allItems = RestrictedItemsData.getAllItems();
    final filteredItems = allItems.where((item) =>
      item.toLowerCase().contains(_searchQuery)
    ).toList();

    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun objet trouvé',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez d\'autres mots-clés',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        final isSelected = _selectedItems.contains(item);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 4),
          child: ListTile(
            leading: Checkbox(
              value: isSelected,
              onChanged: (value) => _toggleItem(item),
            ),
            title: Text(item),
            onTap: () => _toggleItem(item),
          ),
        );
      },
    );
  }

  Widget _buildSelectionSummary() {
    final totalSelected = _selectedCategories.length + _selectedItems.length;
    
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Theme.of(context).primaryColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$totalSelected restriction${totalSelected > 1 ? 's' : ''} sélectionnée${totalSelected > 1 ? 's' : ''}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          TextButton(
            onPressed: _clearAll,
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }

  void _selectCommonRestrictions() {
    setState(() {
      _selectedCategories = [
        'Liquides et gels',
        'Produits dangereux',
        'Objets tranchants',
      ];
      _selectedItems = [
        'Documents officiels',
        'Espèces importantes',
        'Bijoux coûteux',
        'Médicaments sur ordonnance',
      ];
    });
    _notifyChange();
  }

  void _clearAll() {
    setState(() {
      _selectedCategories.clear();
      _selectedItems.clear();
    });
    _notifyChange();
  }
}