import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/flashcard_repository.dart';
import '../../models/flashcard.dart';
import 'import_dialog.dart';
import 'manual_deck_dialog.dart';
import 'review_screen.dart';
import 'deck_screen.dart';

const ink = Color(0xFF252344),
    purple = Color(0xFF6C5AD0),
    muted = Color(0xFF818196);
const accents = [
  purple,
  Color(0xFF319C92),
  Color(0xFFE19A48),
  Color(0xFF608DD4),
];
BoxDecoration panel() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: const Color(0xFFEBEAF2)),
);
String modeLabel(String mode) => switch (mode) {
  'ai' => 'Généré par Claude',
  'offline' => 'Extraction hors ligne',
  'demo' => 'Exemple',
  _ => 'Manuel',
};

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});
  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  final repo = FlashcardRepository();
  List<Deck> decks = [];
  bool loading = true, saving = false;
  String? loadError;
  String search = '';
  int tab = 0;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final result = await repo.load();
      if (mounted) {
        setState(() {
          decks = result;
          loading = false;
          loadError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          loadError = 'La sauvegarde ne peut pas être lue. Vos données ont été conservées.';
        });
      }
    }
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<bool> persist() async {
    setState(() => saving = true);
    try {
      await repo.save(decks);
      return true;
    } catch (_) {
      message('Sauvegarde impossible. Réessayez avant de quitter.');
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  List<Flashcard> get cards => decks.expand((d) => d.cards).toList();
  List<Flashcard> get practiceCards =>
      cards.where((c) => c.needsPractice).toList();
  int get due => cards.where((c) => c.isDue(DateTime.now())).length;
  int get mastery => cards.isEmpty
      ? 0
      : (cards.fold<int>(0, (n, c) => n + c.mastery) / cards.length).round();
  Future<void> importPdf() async {
    final deck = await showDialog<Deck>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImportDialog(repo: repo),
    );
    if (deck != null && mounted) {
      setState(() => decks.add(deck));
      await persist();
    }
  }

  Future<void> createManually() async {
    final deck = await showDialog<Deck>(
      context: context,
      builder: (_) => const ManualDeckDialog(),
    );
    if (deck == null || !mounted) return;
    setState(() => decks.add(deck));
    if (!await persist()) {
      if (mounted) setState(() => decks.remove(deck));
      return;
    }
    if (mounted) await inspect(deck);
  }

  Future<void> demo() async {
    setState(() => decks.add(repo.demo()));
    await persist();
  }

  Future<void> review([Deck? deck]) async {
    final queue =
        (deck?.cards ?? cards).where((c) => c.isDue(DateTime.now())).toList()
          ..sort((a, b) => a.due.compareTo(b.due));
    if (queue.isEmpty) {
      message('Tout est à jour ! Revenez à la prochaine échéance.');
      return;
    }
    await openReview(queue, deck?.title ?? 'Révision du jour');
  }

  Future<void> openReview(
    List<Flashcard> queue,
    String title, {
    bool focused = false,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          cards: queue,
          title: title,
          focused: focused,
          onSave: persist,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> inspect(Deck deck) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeckScreen(deck: deck, save: persist),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> remove(Deck deck) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce paquet ?'),
        content: Text(
          'Les cartes et la progression de « ${deck.title} » seront supprimées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      setState(() => decks.remove(deck));
      await persist();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1050;
          return Row(
            children: [
              if (wide) sidebar(),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 82,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      color: Colors.white,
                      child: Row(
                        children: [
                          if (!wide) ...[
                            const Icon(Icons.school_rounded, color: purple),
                            const SizedBox(width: 12),
                          ],
                          const Expanded(
                            child: Text(
                              'Mon espace d’apprentissage',
                              style: TextStyle(color: muted, fontSize: 14),
                            ),
                          ),
                          if (saving)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          const SizedBox(width: 16),
                          const CircleAvatar(
                            backgroundColor: Color(0xFFEEEAFB),
                            child: Icon(Icons.person_outline, color: purple),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : loadError != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(loadError!),
                                  TextButton(
                                    onPressed: load,
                                    child: const Text('Réessayer'),
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              padding: EdgeInsets.all(wide ? 36 : 20),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 1220,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'APPRENDRE. RÉVISER. RETENIR.',
                                        style: TextStyle(
                                          color: purple,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 32,
                                        runSpacing: 16,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                tab == 0
                                                    ? 'Flashcards intelligentes'
                                                    : 'Votre progression',
                                                style: const TextStyle(
                                                  fontSize: 30,
                                                  fontWeight: FontWeight.w800,
                                                  color: ink,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              const Text(
                                                'Un peu chaque jour. Des connaissances pour longtemps.',
                                                style: TextStyle(color: muted),
                                              ),
                                            ],
                                          ),
                                          FilledButton.icon(
                                            onPressed: importPdf,
                                            icon: const Icon(
                                              Icons.add,
                                              size: 19,
                                            ),
                                            label: const Text(
                                              'Créer depuis un PDF',
                                            ),
                                            style: FilledButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 22,
                                                    vertical: 20,
                                                  ),
                                              backgroundColor: purple,
                                            ),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: saving
                                                ? null
                                                : createManually,
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                            label: const Text(
                                              'Créer manuellement',
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 28),
                                      if (!wide)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 20,
                                          ),
                                          child: SegmentedButton<int>(
                                            segments: const [
                                              ButtonSegment(
                                                value: 0,
                                                label: Text('Mes flashcards'),
                                              ),
                                              ButtonSegment(
                                                value: 1,
                                                label: Text('Progression'),
                                              ),
                                            ],
                                            selected: {tab},
                                            onSelectionChanged: (s) =>
                                                setState(() => tab = s.first),
                                          ),
                                        ),
                                      stats(),
                                      const SizedBox(height: 26),
                                      if (tab == 0) ...[
                                        practicePanel(),
                                        const SizedBox(height: 16),
                                        hero(),
                                        const SizedBox(height: 32),
                                        library(),
                                      ] else
                                        progress(),
                                      const SizedBox(height: 28),
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.lock_outline,
                                            size: 14,
                                            color: muted,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Progression enregistrée sur cet appareil • Révisions adaptées à vos réponses',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: muted,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
  Widget sidebar() => Container(
    width: 242,
    color: Colors.white,
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        const Row(
          children: [
            CircleAvatar(
              backgroundColor: purple,
              child: Icon(Icons.school_rounded, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text(
              'smart\nlearning',
              style: TextStyle(
                fontSize: 19,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 56),
        const Text(
          'MON APPRENTISSAGE',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.5,
            color: muted,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 18),
        nav(Icons.style_outlined, 'Mes flashcards', 0),
        const SizedBox(height: 8),
        nav(Icons.insights_outlined, 'Progression', 1),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F2FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline, color: purple),
              SizedBox(height: 12),
              Text(
                'La régularité fait la différence.',
                style: TextStyle(fontWeight: FontWeight.bold, color: ink),
              ),
              SizedBox(height: 8),
              Text(
                'Quelques minutes de rappel actif valent mieux qu’une longue relecture.',
                style: TextStyle(fontSize: 12, height: 1.6, color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'SMART LEARNING  /  5SAE10',
          style: TextStyle(fontSize: 10, color: muted),
        ),
      ],
    ),
  );
  Widget nav(IconData icon, String title, int index) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    selected: tab == index,
    selectedTileColor: const Color(0xFFEEEAFC),
    selectedColor: purple,
    leading: Icon(icon, size: 21),
    title: Text(
      title,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    onTap: () => setState(() => tab = index),
  );
  Widget stats() => LayoutBuilder(
    builder: (_, c) {
      final items = [
        (Icons.layers_outlined, '${cards.length}', 'Cartes au total', purple),
        (
          Icons.schedule,
          '$due',
          'À réviser maintenant',
          const Color(0xFFE19A48),
        ),
        (
          Icons.psychology_outlined,
          '$mastery %',
          'Indice de mémorisation',
          const Color(0xFF319C92),
        ),
        (
          Icons.check_circle_outline,
          '${cards.fold<int>(0, (s, c) => s + c.reviews)}',
          'Réponses évaluées',
          const Color(0xFF608DD4),
        ),
      ];
      final cols = c.maxWidth < 650 ? 2 : 4;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (final item in items)
            Container(
              width: (c.maxWidth - 14 * (cols - 1)) / cols,
              padding: const EdgeInsets.all(20),
              decoration: panel(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.$1, color: item.$4, size: 23),
                  const SizedBox(height: 16),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.$3,
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
  Widget practicePanel() {
    final queue = practiceCards..sort((a, b) => a.due.compareTo(b.due));
    final count = queue.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: panel(),
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cartes à retravailler · $count',
                style: const TextStyle(
                  color: ink,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                count == 0
                    ? 'Les cartes notées Oublié ou Difficile apparaîtront ici.'
                    : 'Entraînez-vous sur les cartes notées Oublié ou Difficile, même avant leur échéance.',
                style: const TextStyle(color: muted),
              ),
            ],
          ),
          if (count > 0)
            FilledButton.tonalIcon(
              onPressed: () =>
                  openReview(queue, 'Cartes à retravailler', focused: true),
              icon: const Icon(Icons.track_changes),
              label: Text(
                count == 1
                    ? 'Réviser cette carte'
                    : 'Réviser ces $count cartes',
              ),
            ),
        ],
      ),
    );
  }

  Widget hero() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF6250BB), Color(0xFF8775D9)],
      ),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'VOTRE RENDEZ-VOUS MÉMOIRE',
                style: TextStyle(
                  color: Color(0xFFDED6FF),
                  fontSize: 10,
                  letterSpacing: 1.7,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                due > 0
                    ? '$due cartes vous attendent.'
                    : 'Faites de la place au savoir.',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                due > 0
                    ? 'Retrouvez les bonnes notions, au bon moment.\nVotre prochaine session commence ici.'
                    : 'Importez votre cours ou explorez un paquet exemple\npour découvrir la répétition espacée.',
                style: const TextStyle(color: Color(0xFFE4DFF8), height: 1.6),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: due > 0
                    ? () => review()
                    : decks.isEmpty
                    ? demo
                    : importPdf,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: purple,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 18,
                  ),
                ),
                label: Text(
                  due > 0
                      ? 'Commencer la révision'
                      : decks.isEmpty
                      ? 'Essayer le paquet exemple'
                      : 'Importer un cours',
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
              ),
            ],
          ),
        ),
        if (MediaQuery.sizeOf(context).width > 800)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 30),
            child: Icon(
              Icons.auto_awesome_motion_rounded,
              size: 110,
              color: Color(0xFFDDD4FF),
            ),
          ),
      ],
    ),
  );
  Widget library() {
    final filtered = decks
        .where((d) => d.title.toLowerCase().contains(search.toLowerCase()))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Mes paquets  (${decks.length})',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ink,
              ),
            ),
            SizedBox(
              width: 260,
              child: TextField(
                onChanged: (s) => setState(() => search = s),
                decoration: const InputDecoration(
                  hintText: 'Rechercher un paquet…',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(38),
            decoration: panel(),
            child: Column(
              children: [
                const Icon(
                  Icons.library_books_outlined,
                  size: 36,
                  color: purple,
                ),
                const SizedBox(height: 12),
                Text(
                  decks.isEmpty
                      ? 'Votre bibliothèque commence ici'
                      : 'Aucun paquet trouvé',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  decks.isEmpty
                      ? 'Transformez un PDF en cartes à mémoriser, à votre rythme.'
                      : 'Essayez un autre mot-clé.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted),
                ),
                if (decks.isEmpty)
                  TextButton(
                    onPressed: importPdf,
                    child: const Text('Importer mon premier PDF →'),
                  ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (_, c) {
              final cols = c.maxWidth < 630
                  ? 1
                  : c.maxWidth < 1000
                  ? 2
                  : 3;
              return Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  for (final d in filtered)
                    SizedBox(
                      width: (c.maxWidth - 18 * (cols - 1)) / cols,
                      child: deckTile(d),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget deckTile(Deck d) {
    final color = accents[d.color % accents.length];
    final count = d.dueCount(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.style_outlined, color: color),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: 'Options du paquet',
                onSelected: (s) => s == 'delete' ? remove(d) : inspect(d),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Voir et modifier les cartes'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Supprimer le paquet'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            d.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${d.cards.length} cartes • ${modeLabel(d.mode)}',
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Text(
                'Mémorisation',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const Spacer(),
              Text(
                '${d.mastery} %',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: d.mastery / 100,
              minHeight: 6,
              color: color,
              backgroundColor: const Color(0xFFF0EFF5),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  count > 0 ? '$count à réviser' : 'À jour',
                  style: TextStyle(
                    fontSize: 12,
                    color: count > 0
                        ? const Color(0xFFB67D28)
                        : const Color(0xFF319C92),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => inspect(d),
                child: const Text('Voir'),
              ),
              FilledButton.tonal(
                onPressed: count == 0 ? null : () => review(d),
                child: const Text('Réviser'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget progress() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: panel(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Votre mémoire se construit chaque jour',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: ink,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'L’indice est une estimation basée sur vos auto-évaluations : +20 points par rappel réussi, remis à zéro après un oubli. Il ne remplace pas une évaluation des acquis.',
          style: TextStyle(color: muted, height: 1.6),
        ),
        const SizedBox(height: 24),
        for (final d in decks)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.style_outlined, color: purple),
            title: Text(d.title),
            subtitle: Text(
              '${d.cards.where((c) => c.repetitions >= 5).length} maîtrisées • ${d.dueCount(DateTime.now())} à réviser',
            ),
            trailing: Text('${d.mastery} %'),
          ),
        if (decks.isEmpty)
          const Text(
            'Vos statistiques apparaîtront après vos premières révisions.',
          ),
        const Divider(height: 40),
        const Text(
          'Prochaines révisions',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 16),
        for (var day = 0; day < 7; day++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    day == 0
                        ? 'Aujourd’hui'
                        : day == 1
                        ? 'Demain'
                        : 'Dans $day jours',
                    style: const TextStyle(color: muted),
                  ),
                ),
                Expanded(
                  child: LinearProgressIndicator(
                    value: cards.isEmpty ? 0 : scheduled(day) / cards.length,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(6),
                    backgroundColor: const Color(0xFFF0EFF5),
                  ),
                ),
                SizedBox(
                  width: 45,
                  child: Text('${scheduled(day)}', textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        const Text(
          'Oublié : 10 min • Difficile : intervalle × 1,2 • Bien : 1 j, 6 j, puis intervalle × facilité • Facile : intervalle allongé',
          style: TextStyle(color: muted, fontSize: 12, height: 1.6),
        ),
      ],
    ),
  );
  int scheduled(int day) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day + day);
    final end = DateTime(now.year, now.month, now.day + day + 1);
    return cards
        .where(
          (c) => c.due.isBefore(end) && (day == 0 || !c.due.isBefore(start)),
        )
        .length;
  }
}
