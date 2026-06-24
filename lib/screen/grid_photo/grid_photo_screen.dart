import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starvy/navigation/app_routes.dart';
import 'package:starvy/screen/widgets/custom_snack_bar.dart';
import 'package:starvy/theme/app_colors.dart';

import '../../providers/grid_photo_provider.dart';

class GridPhotoScreen extends StatelessWidget {
  const GridPhotoScreen({super.key});

  static final List<Map<String, Color>> _menuColors =
      AppColors.gridMenuCardColors;

  @override
  Widget build(BuildContext context) {
    final templates = GridPhotoProvider.templates;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            itemCount: templates.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemBuilder: (context, index) {
              final template = templates[index];
              return _GridTemplateTile(
                index: index,
                template: template,
                colorSet: _menuColors[index % _menuColors.length],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GridTemplateTile extends StatelessWidget {
  const _GridTemplateTile({
    required this.index,
    required this.template,
    required this.colorSet,
  });

  final int index;
  final GridTemplate template;
  final Map<String, Color> colorSet;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        context.read<GridPhotoProvider>().markSelected(index);

        FirebaseAnalytics.instance.logEvent(
          name: 'grid_template_selected',
          parameters: {
            'title': template.title,
            'rows': template.rows,
            'cols': template.cols,
          },
        );

        CustomSnackBar.show(
          context,
          message: '${template.title} dipilih',
          type: SnackType.info,
        );

        Future.delayed(const Duration(milliseconds: 200), () {
          if (!context.mounted) return;
          context.pushAppRoute(
            AppRoutes.gridChoose,
            arguments: GridChoosePhotoArgs(
              rows: template.rows,
              cols: template.cols,
              title: template.title,
            ),
          );
        });
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: colorSet['bg'],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Icon(template.icon, size: 40, color: colorSet['icon']),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            template.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
