import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.supabaseUrl.contains('YOUR_PROJECT') ||
      AppConfig.supabaseAnonKey.contains('YOUR_SUPABASE')) {
    runApp(const KeaProApp(configured: false));
    return;
  }
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
  );
  runApp(const KeaProApp(configured: true));
}

class KeaProApp extends StatefulWidget {
  const KeaProApp({super.key, required this.configured});
  final bool configured;
  @override
  State<KeaProApp> createState() => _KeaProAppState();
}

class _KeaProAppState extends State<KeaProApp> {
  bool kannada = false;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KEA Pro',
      debugShowCheckedModeBanner: false,
      locale: kannada ? const Locale('kn') : const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('kn')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF155EEF)),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
      ),
      home: widget.configured
          ? AppShell(kannada: kannada, onLanguageChanged: (v) => setState(() => kannada = v))
          : const ConfigurationRequired(),
    );
  }
}

class T {
  static String s(bool kn, String en, String kannada) => kn ? kannada : en;
}

class ConfigurationRequired extends StatelessWidget {
  const ConfigurationRequired({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.school_rounded, size: 64),
        const SizedBox(height: 16),
        const Text('KEA Pro', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text('Configure Supabase in lib/app_config.dart, then restart the app.',
          textAlign: TextAlign.center),
      ]),
    )),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.kannada, required this.onLanguageChanged});
  final bool kannada;
  final ValueChanged<bool> onLanguageChanged;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(kn: widget.kannada, onOpenQuiz: () => setState(() => index = 2)),
      NewsPage(kn: widget.kannada),
      QuizPage(kn: widget.kannada),
      BookmarksPage(kn: widget.kannada),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('KEA Pro', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: () => widget.onLanguageChanged(!widget.kannada),
            child: Text(widget.kannada ? 'English' : 'ಕನ್ನಡ'),
          ),
        ],
      ),
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), label: T.s(widget.kannada,'Home','ಮುಖಪುಟ')),
          NavigationDestination(icon: const Icon(Icons.newspaper_outlined), label: T.s(widget.kannada,'News','ಸುದ್ದಿ')),
          NavigationDestination(icon: const Icon(Icons.quiz_outlined), label: T.s(widget.kannada,'Quiz','ರಸಪ್ರಶ್ನೆ')),
          NavigationDestination(icon: const Icon(Icons.bookmark_outline), label: T.s(widget.kannada,'Saved','ಉಳಿಸಿದವು')),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.kn, required this.onOpenQuiz});
  final bool kn;
  final VoidCallback onOpenQuiz;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(colors: [Color(0xFF155EEF), Color(0xFF6938EF)]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(T.s(kn,'Your government exam journey','ನಿಮ್ಮ ಸರ್ಕಾರಿ ಪರೀಕ್ಷಾ ಪ್ರಯಾಣ'),
            style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(T.s(kn,'Learn a little. Improve every day.','ಪ್ರತಿದಿನ ಕಲಿಯಿರಿ, ಪ್ರಗತಿ ಸಾಧಿಸಿ.'),
            style: const TextStyle(color: Colors.white,fontSize: 23,fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
          FilledButton.tonalIcon(onPressed: onOpenQuiz,
            icon: const Icon(Icons.play_arrow),
            label: Text(T.s(kn,'Start daily quiz','ದೈನಂದಿನ ರಸಪ್ರಶ್ನೆ ಪ್ರಾರಂಭಿಸಿ'))),
        ]),
      ),
      const SizedBox(height: 18),
      Text(T.s(kn,'Study modules','ಅಧ್ಯಯನ ವಿಭಾಗಗಳು'),
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      const Wrap(spacing: 10, runSpacing: 10, children: [
        _ModuleCard(icon: Icons.account_balance, en: 'Polity & Governance', kn: 'ರಾಜ್ಯಶಾಸ್ತ್ರ'),
        _ModuleCard(icon: Icons.history_edu, en: 'Karnataka History', kn: 'ಕರ್ನಾಟಕ ಇತಿಹಾಸ'),
        _ModuleCard(icon: Icons.map, en: 'Geography', kn: 'ಭೂಗೋಳ'),
        _ModuleCard(icon: Icons.science, en: 'Science & Tech', kn: 'ವಿಜ್ಞಾನ ಮತ್ತು ತಂತ್ರಜ್ಞಾನ'),
        _ModuleCard(icon: Icons.eco, en: 'Environment', kn: 'ಪರಿಸರ'),
        _ModuleCard(icon: Icons.computer, en: 'Computer Knowledge', kn: 'ಕಂಪ್ಯೂಟರ್ ಜ್ಞಾನ'),
      ]),
      const SizedBox(height: 18),
      FutureBuilder<List<Map<String,dynamic>>>(
        future: Supabase.instance.client.from('current_affairs_articles')
          .select('id,title,title_kn,summary_en,summary_kn,source_name,published_at')
          .eq('review_status','approved').order('published_at',ascending:false).limit(5),
        builder: (context, snap) => _NewsPreview(kn: kn, snapshot: snap),
      ),
    ],
  );
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.icon, required this.en, required this.kn});
  final IconData icon; final String en; final String kn;
  @override
  Widget build(BuildContext context) => SizedBox(width: 164, child: Card(
    child: Padding(padding: const EdgeInsets.all(14), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(kn == '' ? en : en, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(kn, style: Theme.of(context).textTheme.bodySmall),
      ],
    )),
  ));
}

class _NewsPreview extends StatelessWidget {
  const _NewsPreview({required this.kn, required this.snapshot});
  final bool kn; final AsyncSnapshot<List<Map<String,dynamic>>> snapshot;
  @override
  Widget build(BuildContext context) {
    if (snapshot.hasError) return _ErrorCard(message: 'Could not load current affairs. Check connection or database policies.');
    if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
    final rows = snapshot.data!;
    if (rows.isEmpty) return const _ErrorCard(message: 'No approved articles yet. Run the ingestion job and approve content.');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(T.s(kn,'Latest current affairs','ಇತ್ತೀಚಿನ ಪ್ರಚಲಿತ ವಿದ್ಯಮಾನಗಳು'),
        style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      ...rows.map((r) => Card(child: ListTile(
        title: Text((kn ? r['title_kn'] : r['title'])?.toString() ?? r['title'].toString()),
        subtitle: Text('${r['source_name']} • ${r['published_at']}'),
        isThreeLine: false,
      ))),
    ]);
  }
}

class NewsPage extends StatefulWidget {
  const NewsPage({super.key, required this.kn});
  final bool kn;
  @override
  State<NewsPage> createState() => _NewsPageState();
}
class _NewsPageState extends State<NewsPage> {
  final search = TextEditingController();
  String region = 'all';
  bool loading = false;
  List<Map<String,dynamic>> rows = [];
  String? error;
  Future<void> load() async {
    setState(() {loading=true;error=null;});
    try {
      var query = Supabase.instance.client.from('current_affairs_articles')
        .select('id,title,title_kn,summary_en,summary_kn,source_name,canonical_url,published_at,region,tags')
        .eq('review_status','approved');
      if (region != 'all') query = query.eq('region',region);
      if (search.text.trim().isNotEmpty) query = query.ilike('title','%${search.text.trim()}%');
      final result = await query.order('published_at',ascending:false).limit(50);
      if (mounted) setState(() => rows=List<Map<String,dynamic>>.from(result));
    } catch (e) { if (mounted) setState(() => error='Unable to load live articles: $e'); }
    finally { if (mounted) setState(() => loading=false); }
  }
  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      TextField(controller: search, onSubmitted: (_) => load(),
        decoration: InputDecoration(prefixIcon: const Icon(Icons.search),
          hintText: T.s(widget.kn,'Search current affairs','ಪ್ರಚಲಿತ ವಿದ್ಯಮಾನಗಳನ್ನು ಹುಡುಕಿ'),
          suffixIcon: IconButton(onPressed: load, icon: const Icon(Icons.search)),
          border: const OutlineInputBorder())),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(
          value: region, decoration: const InputDecoration(labelText:'Region'),
          items: [
            DropdownMenuItem(value:'all',child:Text(T.s(widget.kn,'All regions','ಎಲ್ಲ ಪ್ರದೇಶಗಳು'))),
            DropdownMenuItem(value:'india',child:Text(T.s(widget.kn,'India','ಭಾರತ'))),
            DropdownMenuItem(value:'karnataka',child:Text(T.s(widget.kn,'Karnataka','ಕರ್ನಾಟಕ'))),
            DropdownMenuItem(value:'international',child:Text(T.s(widget.kn,'International','ಅಂತರರಾಷ್ಟ್ರೀಯ'))),
          ], onChanged:(v){if(v!=null){region=v;load();}})),
        IconButton(onPressed:load, icon: const Icon(Icons.refresh)),
      ]),
    ])),
    if (loading) const LinearProgressIndicator(),
    if (error != null) Padding(padding:const EdgeInsets.all(12),child:Text(error!)),
    Expanded(child: RefreshIndicator(onRefresh:load,child: ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(), itemCount:rows.length,
      itemBuilder:(context,i) {
        final r=rows[i];
        return Card(margin:const EdgeInsets.fromLTRB(12,4,12,4), child: ListTile(
          title:Text((widget.kn ? r['title_kn'] : r['title'])?.toString() ?? ''),
          subtitle:Text((widget.kn ? r['summary_kn'] : r['summary_en'])?.toString() ?? ''),
          trailing:IconButton(icon:const Icon(Icons.bookmark_add_outlined),
            onPressed:()=>_bookmarkArticle(context,r['id'] as String)),
          onTap:()=>showModalBottomSheet(context:context,isScrollControlled:true,
            builder:(_)=>_ArticleDetails(row:r,kn:widget.kn)),
        ));
      },
    ))),
  ]);
}

Future<void> _bookmarkArticle(BuildContext context, String id) async {
  final user=Supabase.instance.client.auth.currentUser;
  if(user==null){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Sign in to save bookmarks.')));return;}
  try {
    await Supabase.instance.client.from('user_bookmarks').upsert({
      'user_id':user.id,'target_type':'article','article_id':id
    },onConflict:'user_id,article_id',ignoreDuplicates:true);
    if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Article saved.')));
  } catch(e) {
    if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not save bookmark: $e')));
  }
}

class _ArticleDetails extends StatelessWidget {
  const _ArticleDetails({required this.row,required this.kn});
  final Map<String,dynamic> row; final bool kn;
  @override
  Widget build(BuildContext context)=>SafeArea(child:Padding(
    padding:const EdgeInsets.all(20),child:SingleChildScrollView(child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
        Text((kn?row['title_kn']:row['title'])?.toString()??'',style:Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height:12),
        Text((kn?row['summary_kn']:row['summary_en'])?.toString()??''),
        const SizedBox(height:12),
        Text('${row['source_name']} • ${row['published_at']}'),
        const SizedBox(height:12),
        SelectableText(row['canonical_url']?.toString()??''),
      ],
    )),
  ));
}

class QuizPage extends StatefulWidget {
  const QuizPage({super.key, required this.kn});
  final bool kn;
  @override
  State<QuizPage> createState()=>_QuizPageState();
}
class _QuizPageState extends State<QuizPage> {
  List<Map<String,dynamic>> questions=[];
  final Map<String,int> answers={};
  bool loading=true, submitted=false;
  String? error;
  int secondsLeft=300;
  Timer? timer;
  @override
  void initState(){super.initState();_load();}
  Future<void> _load() async {
    try{
      final rows=await Supabase.instance.client.from('questions')
        .select('id,question_en,question_kn,options_en,options_kn,correct_option,explanation_en,explanation_kn,category_id')
        .eq('is_published',true).order('created_at',ascending:false).limit(5);
      if(mounted){setState(()=>questions=List<Map<String,dynamic>>.from(rows));_startTimer();}
    }catch(e){if(mounted)setState(()=>error='Could not load quiz: $e');}
    finally{if(mounted)setState(()=>loading=false);}
  }
  void _startTimer(){
    timer?.cancel();
    timer=Timer.periodic(const Duration(seconds:1),(t){
      if(!mounted||submitted){t.cancel();return;}
      if(secondsLeft<=1){setState(()=>secondsLeft=0);_submit();t.cancel();}
      else setState(()=>secondsLeft--);
    });
  }
  Future<void> _submit() async {
    if(submitted)return;
    timer?.cancel();
    setState(()=>submitted=true);
    final correct=questions.where((q)=>answers[q['id']] == q['correct_option']).length;
    final user=Supabase.instance.client.auth.currentUser;
    if(user!=null && questions.isNotEmpty){
      try{
        final attempt=await Supabase.instance.client.from('test_attempts').insert({
          'user_id':user.id,'mode':'daily_quiz','started_at':DateTime.now().subtract(Duration(seconds:300-secondsLeft)).toUtc().toIso8601String(),
          'submitted_at':DateTime.now().toUtc().toIso8601String(),'duration_seconds':300-secondsLeft,
          'total_questions':questions.length,'correct_count':correct,
          'wrong_count':answers.length-correct,'skipped_count':questions.length-answers.length,
          'score':correct,'max_score':questions.length,'status':'submitted'
        }).select('id').single();
        final attemptId=attempt['id'] as String;
        for(final q in questions){
          final selected=answers[q['id']];
          await Supabase.instance.client.from('test_attempt_answers').upsert({
            'attempt_id':attemptId,'question_id':q['id'],'selected_option':selected,
            'is_correct':selected==null?null:selected==q['correct_option'],
            'marks_awarded':selected==q['correct_option']?1:0
          });
        }
      }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Quiz scored locally, but saving attempt failed: $e')));}
    }
  }
  @override
  void dispose(){timer?.cancel();super.dispose();}
  @override
  Widget build(BuildContext context){
    if(loading)return const Center(child:CircularProgressIndicator());
    if(error!=null)return Center(child:Padding(padding:const EdgeInsets.all(20),child:Text(error!)));
    if(questions.isEmpty)return const _ErrorCard(message:'No published questions yet. Run ingestion and approve questions in the database.');
    final correct=questions.where((q)=>answers[q['id']]==q['correct_option']).length;
    return Column(children:[
      Padding(padding:const EdgeInsets.all(12),child:Row(children:[
        Expanded(child:Text(T.s(widget.kn,'Daily 5-question quiz','ದೈನಂದಿನ 5 ಪ್ರಶ್ನೆಗಳ ರಸಪ್ರಶ್ನೆ'),style:Theme.of(context).textTheme.titleLarge)),
        Chip(label:Text('${secondsLeft~/60}:${(secondsLeft%60).toString().padLeft(2,'0')}')),
      ])),
      Expanded(child:ListView.builder(padding:const EdgeInsets.all(12),itemCount:questions.length,
        itemBuilder:(context,i){
          final q=questions[i];final id=q['id'] as String;
          final options=List<String>.from((widget.kn?q['options_kn']:q['options_en']) as List? ?? q['options_en'] as List);
          return Card(margin:const EdgeInsets.only(bottom:12),child:Padding(padding:const EdgeInsets.all(16),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('${i+1}. ${(widget.kn?q['question_kn']:q['question_en'])}',style:const TextStyle(fontWeight:FontWeight.bold)),
              const SizedBox(height:8),
              ...List.generate(options.length,(j)=>RadioListTile<int>(
                contentPadding:EdgeInsets.zero,dense:true,title:Text(options[j]),
                value:j,groupValue:answers[id],onChanged:submitted?null:(v)=>setState(()=>answers[id]=v!))),
              if(submitted) Container(width:double.infinity,padding:const EdgeInsets.all(10),
                decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(12)),
                child:Text('${T.s(widget.kn,'Correct answer','ಸರಿಯಾದ ಉತ್ತರ')}: ${options[q['correct_option']]}\\n${widget.kn?q['explanation_kn']:q['explanation_en']}')),
            ],
          )));
        })),
      Padding(padding:const EdgeInsets.all(12),child:submitted
        ?Text(T.s(widget.kn,'Score: $correct / ${questions.length}','ಅಂಕಗಳು: $correct / ${questions.length}'))
        :FilledButton(onPressed:_submit,child:Text(T.s(widget.kn,'Submit quiz','ರಸಪ್ರಶ್ನೆ ಸಲ್ಲಿಸಿ')))),
    ]);
  }
}

class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key,required this.kn});final bool kn;
  @override State<BookmarksPage> createState()=>_BookmarksPageState();
}
class _BookmarksPageState extends State<BookmarksPage>{
  Future<List<Map<String,dynamic>>> _load() async {
    final user=Supabase.instance.client.auth.currentUser;
    if(user==null)return [];
    final data=await Supabase.instance.client.from('user_bookmarks')
      .select('id,created_at,current_affairs_articles(title,title_kn,summary_en,summary_kn,source_name)')
      .eq('user_id',user.id).order('created_at',ascending:false);
    return List<Map<String,dynamic>>.from(data);
  }
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(
    future:_load(),builder:(context,s){
      if(s.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
      if(s.hasError)return Center(child:Text('Unable to load bookmarks: ${s.error}'));
      final rows=s.data??[];
      if(rows.isEmpty)return const _ErrorCard(message:'No saved articles yet. Sign in and bookmark a current-affairs article.');
      return ListView.builder(itemCount:rows.length,itemBuilder:(context,i){
        final r=rows[i];final article=r['current_affairs_articles'] as Map<String,dynamic>?;
        return ListTile(title:Text((widget.kn?article?['title_kn']:article?['title'])?.toString()??'Saved item'),
          subtitle:Text((widget.kn?article?['summary_kn']:article?['summary_en'])?.toString()??''),
          trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:()async{
            await Supabase.instance.client.from('user_bookmarks').delete().eq('id',r['id']);
            if(context.mounted)setState((){});
          }));
      });
    });
}

class _ErrorCard extends StatelessWidget{
  const _ErrorCard({required this.message});final String message;
  @override Widget build(BuildContext context)=>Card(child:Padding(
    padding:const EdgeInsets.all(18),child:Row(children:[
      const Icon(Icons.info_outline),const SizedBox(width:12),Expanded(child:Text(message))
    ]),
  ));
}
