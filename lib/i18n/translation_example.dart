// Ejemplo de cómo usar el TranslationService

import 'package:flutter/material.dart';
import 'package:thisjowi/i18n/translation_service.dart';
import 'package:thisjowi/i18n/translations.dart';

void initializeDynamicTranslations() {
  // Puedes agregar traducciones desde cualquier lugar
  TranslationService.addTranslations({
    "Feature 1": {
      "en": "Feature 1",
      "es": "Característica 1",
    },
    "Feature 2": {
      "en": "Feature 2",
      "es": "Característica 2",
    },
    // Puedes agregar tantas como necesites
  });
}

// Ejemplo de widget
class ExampleWidget extends StatelessWidget {
  const ExampleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Opción 1: Traducciones estáticas (i18n_extension)
        Text("Cancel".i18n),
        
        // Opción 2: Traducciones dinámicas (TranslationService)
        Text("Feature 1".tr(context)),
        Text("Feature 2".tr(context)),
      ],
    );
  }
}
