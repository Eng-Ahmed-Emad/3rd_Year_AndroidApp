import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

void main() {
  runApp(ExploitDBApp());
}

class ExploitDBApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exploit-DB Viewer',
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.greenAccent,
          surface: Color(0xFF202020),
          background: Color(0xFF121212),
          error: Colors.redAccent,
        ),
        brightness: Brightness.dark,
        useMaterial3: true,
        cardTheme: CardTheme(
          color: Color(0xFF1E1E1E),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          elevation: 0,
        ),
        scaffoldBackgroundColor: Color(0xFF121212),
      ),
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Exploit {
  final String id;
  final String date;
  final String title;
  final String type;
  final String platform;
  final String author;
  final String port;
  final String protocol;

  Exploit({
    required this.id,
    required this.date,
    required this.title,
    required this.type,
    required this.platform,
    required this.author,
    required this.port,
    required this.protocol,
  });

  factory Exploit.fromCsvRow(List<dynamic> row) {
    String title = row[2].toString();
    String detectedProtocol = _detectProtocol(title);

    return Exploit(
      id: row[0].toString(),
      date: row[1].toString(),
      title: title,
      type: row[3].toString(),
      platform: row[4].toString(),
      author: row[6].toString(),
      port: row[5].toString(),
      protocol: detectedProtocol,
    );
  }

  static String _detectProtocol(String title) {
    title = title.toLowerCase();

    if (title.contains('http') || title.contains('web')) return 'HTTP';
    if (title.contains('ftp')) return 'FTP';
    if (title.contains('smb') || title.contains('samba')) return 'SMB';
    if (title.contains('smtp') || title.contains('email')) return 'SMTP';
    if (title.contains('dns')) return 'DNS';
    if (title.contains('ssh')) return 'SSH';
    if (title.contains('telnet')) return 'TELNET';
    if (title.contains('rdp')) return 'RDP';
    if (title.contains('sql')) return 'SQL';
    if (title.contains('ldap')) return 'LDAP';
    if (title.contains('nfs')) return 'NFS';

    return 'Other';
  }

  String getExploitUrl() {
    return 'https://www.exploit-db.com/exploits/$id';
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Exploit> _exploits = [];
  List<Exploit> _filteredExploits = [];
  bool _isLoading = true;
  String _error = '';

  TextEditingController _searchController = TextEditingController();
  String? _selectedProtocol;

  List<String> _availableProtocols = [
    'HTTP', 'FTP', 'SMB', 'SMTP', 'DNS', 'SSH',
    'TELNET', 'RDP', 'SQL', 'LDAP', 'NFS', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _fetchExploits();
  }

  Future<void> _fetchExploits() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Try multiple data sources in sequence
      bool success = await _tryFetchFromExploitDB() ||
          await _tryFetchFromGitHub() ||
          await _loadSampleData();

      if (!success) {
        setState(() {
          _error = 'Failed to fetch exploits from all available sources';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error fetching exploits: $e';
        _isLoading = false;
      });
    }
  }

  Future<bool> _tryFetchFromExploitDB() async {
    try {
      // Use Exploit-DB API for searching exploits
      final response = await http.get(
        Uri.parse('https://www.exploit-db.com/search?type=exploits&format=json'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['data'] != null && jsonData['data'] is List) {
          List<Exploit> exploits = _parseExploitDBJson(jsonData['data']);

          setState(() {
            _exploits = exploits;
            _filteredExploits = exploits;
            _isLoading = false;
          });
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error fetching from Exploit-DB API: $e');
      return false;
    }
  }

  Future<bool> _tryFetchFromGitHub() async {
    try {
      // GitHub raw URL to Exploit-DB CSV with a timeout
      final response = await http.get(Uri.parse(
          'https://raw.githubusercontent.com/offensive-security/exploitdb/master/files_exploits.csv'))
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final csvData = const CsvToListConverter().convert(response.body);

        // Skip header row
        List<Exploit> exploits = [];
        for (int i = 1; i < csvData.length; i++) {
          if (csvData[i].length >= 7) {
            exploits.add(Exploit.fromCsvRow(csvData[i]));
          }
        }

        setState(() {
          _exploits = exploits;
          _filteredExploits = exploits;
          _isLoading = false;
        });
        return true;
      }
      return false;
    } catch (e) {
      print('Error fetching from GitHub: $e');
      return false;
    }
  }

  Future<bool> _loadSampleData() async {
    try {
      // Load sample data from assets
      final jsonString = await DefaultAssetBundle.of(context).loadString('assets/sample_data.json');
      final List<dynamic> jsonData = json.decode(jsonString);

      List<Exploit> sampleExploits = [];
      for (var item in jsonData) {
        String title = item['title']?.toString() ?? '';
        String detectedProtocol = Exploit._detectProtocol(title);

        sampleExploits.add(Exploit(
          id: item['id']?.toString() ?? '',
          date: item['date_published']?.toString() ?? '',
          title: title,
          type: item['type']?.toString() ?? '',
          platform: item['platform']?.toString() ?? '',
          author: item['author']?.toString() ?? '',
          port: item['port']?.toString() ?? '',
          protocol: detectedProtocol,
        ));
      }

      setState(() {
        _exploits = sampleExploits;
        _filteredExploits = sampleExploits;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Using sample data - no internet connection available'),
          duration: Duration(seconds: 5),
          backgroundColor: Colors.orange,
        ),
      );

      return true;
    } catch (e) {
      print('Error loading sample data: $e');
      setState(() {
        _error = 'Failed to load sample data: $e';
        _isLoading = false;
      });
      return false;
    }
  }

  List<Exploit> _parseExploitDBJson(List<dynamic> data) {
    List<Exploit> exploits = [];

    for (var item in data) {
      try {
        String title = item['title']?.toString() ?? '';
        String detectedProtocol = Exploit._detectProtocol(title);

        exploits.add(Exploit(
          id: item['id']?.toString() ?? '',
          date: item['date_published']?.toString() ?? '',
          title: title,
          type: item['type']?.toString() ?? '',
          platform: item['platform']?.toString() ?? '',
          author: item['author']?.toString() ?? '',
          port: item['port']?.toString() ?? '',
          protocol: detectedProtocol,
        ));
      } catch (e) {
        print('Error parsing exploit: $e');
      }
    }

    return exploits;
  }

  List<Exploit> _generateSampleExploits() {
    return [
      Exploit(
        id: '12345',
        date: '2023-05-15',
        title: 'Apache Tomcat Remote Code Execution',
        type: 'webapps',
        platform: 'multiple',
        author: 'Security Researcher',
        port: '8080',
        protocol: 'HTTP',
      ),
      Exploit(
        id: '23456',
        date: '2023-04-20',
        title: 'MySQL Authentication Bypass',
        type: 'remote',
        platform: 'linux',
        author: 'Database Expert',
        port: '3306',
        protocol: 'SQL',
      ),
      Exploit(
        id: '51706',
        date: '2023-03-10',
        title: 'FTP Server Buffer Overflow',
        type: 'remote',
        platform: 'windows',
        author: 'Anonymous',
        port: '21',
        protocol: 'FTP',
      ),
      Exploit(
        id: '45678',
        date: '2023-02-28',
        title: 'SMB Protocol Vulnerability',
        type: 'remote',
        platform: 'windows',
        author: 'File Sharing Expert',
        port: '445',
        protocol: 'SMB',
      ),
      Exploit(
        id: '56789',
        date: '2023-01-15',
        title: 'SSH Authentication Weakness',
        type: 'remote',
        platform: 'multiple',
        author: 'Secure Shell Researcher',
        port: '22',
        protocol: 'SSH',
      ),
      Exploit(
        id: '67890',
        date: '2022-12-20',
        title: 'DNS Server Spoofing Attack',
        type: 'remote',
        platform: 'multiple',
        author: 'Network Security Expert',
        port: '53',
        protocol: 'DNS',
      ),
      Exploit(
        id: '78901',
        date: '2022-11-05',
        title: 'SMTP Mail Server Injection',
        type: 'remote',
        platform: 'linux',
        author: 'Email Security Researcher',
        port: '25',
        protocol: 'SMTP',
      ),
      Exploit(
        id: '89012',
        date: '2022-10-10',
        title: 'RDP Session Hijacking',
        type: 'remote',
        platform: 'windows',
        author: 'Remote Access Expert',
        port: '3389',
        protocol: 'RDP',
      ),
      Exploit(
        id: '90123',
        date: '2022-09-20',
        title: 'LDAP Injection Vulnerability',
        type: 'remote',
        platform: 'multiple',
        author: 'Directory Services Researcher',
        port: '389',
        protocol: 'LDAP',
      ),
      Exploit(
        id: '01234',
        date: '2022-08-15',
        title: 'NFS Unauthorized Access',
        type: 'remote',
        platform: 'linux',
        author: 'File System Expert',
        port: '2049',
        protocol: 'NFS',
      ),
    ];
  }

  void _filterExploits() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredExploits = _exploits.where((exploit) {
        bool matchesSearch = query.isEmpty ||
            exploit.title.toLowerCase().contains(query) ||
            exploit.author.toLowerCase().contains(query) ||
            exploit.platform.toLowerCase().contains(query) ||
            exploit.type.toLowerCase().contains(query);

        bool matchesProtocol = _selectedProtocol == null ||
            exploit.protocol == _selectedProtocol;

        return matchesSearch && matchesProtocol;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Exploit-DB Viewer'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchExploits,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search exploits...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onChanged: (_) => _filterExploits(),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Protocol',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    value: _selectedProtocol,
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text('All Protocols'),
                      ),
                      ..._availableProtocols.map((protocol) => DropdownMenuItem(
                        value: protocol,
                        child: Text(protocol),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedProtocol = value;
                        _filterExploits();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildExploitsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExploitsList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading exploits...'),
          ],
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(_error,
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              onPressed: _fetchExploits,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredExploits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No exploits found matching your criteria',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            if (_searchController.text.isNotEmpty || _selectedProtocol != null)
              ElevatedButton.icon(
                icon: Icon(Icons.clear),
                label: Text('Clear Filters'),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _selectedProtocol = null;
                    _filterExploits();
                  });
                },
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredExploits.length,
      itemBuilder: (context, index) {
        final exploit = _filteredExploits[index];
        return ExploitListItem(exploit: exploit);
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class ExploitListItem extends StatelessWidget {
  final Exploit exploit;

  const ExploitListItem({required this.exploit});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(exploit.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text('Platform: ${exploit.platform} | Type: ${exploit.type}'),
            Text('Date: ${exploit.date} | Author: ${exploit.author}'),
          ],
        ),
        trailing: Chip(
          label: Text(exploit.protocol),
          backgroundColor: _getColorForProtocol(exploit.protocol),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExploitDetailPage(exploit: exploit),
            ),
          );
        },
      ),
    );
  }

  Color _getColorForProtocol(String protocol) {
    switch (protocol) {
      case 'HTTP': return Colors.blue.withOpacity(0.7);
      case 'FTP': return Colors.green.withOpacity(0.7);
      case 'SMB': return Colors.orange.withOpacity(0.7);
      case 'SMTP': return Colors.purple.withOpacity(0.7);
      case 'DNS': return Colors.amber.withOpacity(0.7);
      case 'SSH': return Colors.teal.withOpacity(0.7);
      case 'TELNET': return Colors.pink.withOpacity(0.7);
      case 'RDP': return Colors.indigo.withOpacity(0.7);
      case 'SQL': return Colors.red.withOpacity(0.7);
      case 'LDAP': return Colors.cyan.withOpacity(0.7);
      case 'NFS': return Colors.lightGreen.withOpacity(0.7);
      default: return Colors.grey.withOpacity(0.7);
    }
  }
}

class ExploitDetailPage extends StatelessWidget {
  final Exploit exploit;

  const ExploitDetailPage({required this.exploit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Exploit Details'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exploit.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildInfoRow('ID', exploit.id),
                    _buildInfoRow('Type', exploit.type),
                    _buildInfoRow('Platform', exploit.platform),
                    _buildInfoRow('Date', exploit.date),
                    _buildInfoRow('Author', exploit.author),
                    _buildInfoRow('Protocol', exploit.protocol),
                    if (exploit.port.isNotEmpty) _buildInfoRow('Port', exploit.port),
                    SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: Icon(Icons.open_in_browser),
                      label: Text('View on Exploit-DB'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 50),
                      ),
                      onPressed: () async {
                        final url = exploit.getExploitUrl();
                        if (await canLaunch(url)) {
                          await launch(url);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not open URL: $url')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[400],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}