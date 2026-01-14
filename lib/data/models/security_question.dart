class SecurityQuestion {
  final int id;
  final String question;

  const SecurityQuestion({
    required this.id,
    required this.question,
  });

  static const List<SecurityQuestion> predefinedQuestions = [
    SecurityQuestion(id: 1, question: "quel est le nom de votre premier animal de compagnie"),
    SecurityQuestion(id: 2, question: "dans quelle ville etes vous ne"),
    SecurityQuestion(id: 3, question: "quel est votre plat prefere"),
    SecurityQuestion(id: 4, question: "quel est le nom de votre meilleur ami denfance"),
    SecurityQuestion(id: 5, question: "quelle est votre couleur preferee"),
    SecurityQuestion(id: 6, question: "quel est le nom de votre ecole primaire"),
    SecurityQuestion(id: 7, question: "quel est votre film prefere"),
    SecurityQuestion(id: 8, question: "quel est le nom de votre premier professeur"),
    SecurityQuestion(id: 9, question: "quelle est votre chanson preferee"),
    SecurityQuestion(id: 10, question: "quel est votre sport prefere"),
    SecurityQuestion(id: 11, question: "quel est le nom de votre rue denfance"),
    SecurityQuestion(id: 12, question: "quelle est votre saison preferee"),
    SecurityQuestion(id: 13, question: "quel est votre livre prefere"),
    SecurityQuestion(id: 14, question: "quel est le nom de votre premier emploi"),
    SecurityQuestion(id: 15, question: "quelle est votre marque de voiture preferee"),
  ];

  /// Normalise une réponse (supprime majuscules et caractères spéciaux)
  static String normalizeAnswer(String answer) {
    return answer
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Vérifie si deux réponses correspondent
  static bool answersMatch(String answer1, String answer2) {
    return normalizeAnswer(answer1) == normalizeAnswer(answer2);
  }

  @override
  String toString() => question;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SecurityQuestion && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}