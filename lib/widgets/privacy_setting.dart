import 'package:flutter/material.dart';

class PrivacySetting extends StatelessWidget {
  final String title;
  const PrivacySetting({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Text(
                'Privacy ',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(
              height: 10.0,
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: const Padding(
                padding: EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PrivacyCard(
                      title: 'Call ',
                      subtitle: 'My Contacts',
                    ),
                    Divider(),
                    PrivacyCard(
                      title: 'Online Status & Last Seen ',
                      subtitle: 'My Contacts',
                    ),
                    Divider(),
                    PrivacyCard(
                      title: 'Input Status',
                      subtitle: 'My Contacts',
                    ),
                    Divider(),
                    PrivacyCard(
                      title: 'Read recipts',
                      subtitle: 'My Contacts',
                    ),
                    Divider(),
                    PrivacyCard(
                      title: 'Group',
                      subtitle: 'Nobody',
                    ),
                    Divider(),
                    PrivacyCard(
                      title: 'Voice Messages',
                      subtitle: 'Everyone',
                    ),
                    Divider(),
                    PrivacyCard(
                      title: 'Story',
                      subtitle: '',
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class PrivacyCard extends StatelessWidget {
  final String title;
  final String subtitle;
  const PrivacyCard({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            size: 16.0,
            color: Colors.grey,
          )
        ],
      ),
    );
  }
}
