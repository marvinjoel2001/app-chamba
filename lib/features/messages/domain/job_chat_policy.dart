class JobChatPolicy {
  const JobChatPolicy._();

  static const contactAlert =
      'Por tu seguridad, no compartas teléfonos, redes sociales, correos, enlaces ni datos de pagos externos. Coordina este trabajo dentro de Chamba.';
  static const quickReplies = [
    '¿Dónde ingreso?',
    'Cambiar horario',
    'Ya estoy llegando',
    'Tengo un problema',
  ];

  static String normalize(String content) {
    var text = content.toLowerCase().replaceAll(
        RegExp(r'[\u0300-\u036f\u200b-\u200f\u202a-\u202e\u2060-\u206f\ufeff]'),
        '');
    const accents = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n'
    };
    accents.forEach((key, value) => text = text.replaceAll(key, value));
    text = String.fromCharCodes(text.runes.map((char) {
      if (char >= 0xff01 && char <= 0xff5e) return char - 0xfee0;
      if (char >= 0x0660 && char <= 0x0669) return char - 0x0660 + 48;
      if (char >= 0x06f0 && char <= 0x06f9) return char - 0x06f0 + 48;
      return char;
    }));
    const digits = {
      'cero': '0',
      'uno': '1',
      'dos': '2',
      'tres': '3',
      'cuatro': '4',
      'cinco': '5',
      'seis': '6',
      'siete': '7',
      'ocho': '8',
      'nueve': '9'
    };
    return text
        .replaceAll(RegExp(r'\b(arroba|at sign)\b'), '@')
        .replaceAll(RegExp(r'\b(punto|dot)\b'), '.')
        .replaceAllMapped(
            RegExp(
                r'\b(cero|uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve)\b'),
            (match) => digits[match[0]]!);
  }

  static bool containsExternalContact(String content) {
    final text = normalize(content);
    final compact = text.replaceAll(RegExp('[^a-z0-9]'), '');
    return [
          r'(?:\+?\d[\s().\-/]*){7,}',
          r'@\s*[a-z0-9_]',
          r'(?:https?|ftp):|www\s*\.|(?:wa|t)\s*\.\s*me\b',
          r'\b[a-z0-9-]+\.[a-z]{2,24}\b',
          r'\b[a-z0-9-]+\s*\.\s*(?:com|net|org|io|app|me|co|bo|ly|gg|dev|xyz|info|biz|site|online|social|link|pro|tv|us|uk|es|br|pe|cl|ar|mx|ec)\b',
          r'\b(?:wsp|wpp|whats|insta|ig|fb|yape|plin|usdt|btc|iban|swift|cbu|cvu|sinpe)\b',
          r'\b(?:telefono|celular|correo|email|e-mail|gmail|hotmail|outlook|redes sociales|numero de contacto)\b',
          r'\b(?:cuenta bancaria|numero de cuenta|tarjeta bancaria|pago externo|pagar? (?:por|fuera)|deposit[oa]|transfer(?:encia|ir)|qr (?:de )?pago|fuera de chamba)\b',
        ].any((pattern) => RegExp(pattern).hasMatch(text)) ||
        RegExp(r'wh?ats?app|wh?atsap|wasap|guasap|telegram|instagram|facebook|tiktok|snapchat|linkedin|messenger|discord|paypal|binance|mercadopago|westernunion|moneygram|cashapp')
            .hasMatch(compact);
  }
}
