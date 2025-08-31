import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateTimePickerField extends StatefulWidget {
  final String label;
  final IconData icon;
  final DateTime? selectedDateTime;
  final DateTime? minimumDate;
  final Function(DateTime) onDateTimeSelected;

  const DateTimePickerField({
    super.key,
    required this.label,
    required this.icon,
    this.selectedDateTime,
    this.minimumDate,
    required this.onDateTimeSelected,
  });

  @override
  State<DateTimePickerField> createState() => _DateTimePickerFieldState();
}

class _DateTimePickerFieldState extends State<DateTimePickerField> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _selectDateTime(context),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: Icon(widget.icon),
          border: const OutlineInputBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.selectedDateTime != null
                    ? _formatDateTime(widget.selectedDateTime!)
                    : 'Sélectionner la date et l\'heure',
                style: TextStyle(
                  color: widget.selectedDateTime != null
                      ? Theme.of(context).textTheme.bodyLarge?.color
                      : Theme.of(context).hintColor,
                ),
              ),
            ),
            Icon(
              Icons.calendar_today,
              size: 20,
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final dateFormatter = DateFormat('dd MMM yyyy', 'fr_FR');
    final timeFormatter = DateFormat('HH:mm', 'fr_FR');
    
    return '${dateFormatter.format(dateTime)} à ${timeFormatter.format(dateTime)}';
  }

  Future<void> _selectDateTime(BuildContext context) async {
    try {
      final now = DateTime.now();
      final initialDate = widget.selectedDateTime ?? widget.minimumDate ?? now.add(const Duration(days: 1));
      final firstDate = widget.minimumDate ?? now;
      final lastDate = now.add(const Duration(days: 365));

      // Select date first
      final selectedDate = await showDatePicker(
        context: context,
        initialDate: initialDate.isAfter(firstDate) && initialDate.isBefore(lastDate) 
            ? initialDate 
            : (firstDate.isAfter(now) ? firstDate : now.add(const Duration(days: 1))),
        firstDate: firstDate,
        lastDate: lastDate,
        locale: const Locale('fr', 'FR'),
      );

      if (selectedDate == null || !mounted) return;

      // Then select time
      final selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );

      if (selectedTime == null || !mounted) return;

      // Combine date and time
      final newSelectedDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      // Validate that the selected datetime is in the future
      if (newSelectedDateTime.isBefore(now)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La date et l\'heure doivent être dans le futur'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Validate against minimum date if provided
      if (widget.minimumDate != null && newSelectedDateTime.isBefore(widget.minimumDate!)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('La date doit être après ${_formatDateTime(widget.minimumDate!)}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Use a small delay to ensure the UI is stable before calling the callback
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          widget.onDateTimeSelected(newSelectedDateTime);
        }
      });
    } catch (e) {
      // Handle any errors that might occur during date/time selection
      debugPrint('Error in _selectDateTime: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la sélection de la date/heure'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}