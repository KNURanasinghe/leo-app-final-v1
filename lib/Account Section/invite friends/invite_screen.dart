import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class InviteFriendsPage extends StatelessWidget {
  const InviteFriendsPage({super.key});

  void _showInviteDialog(BuildContext context) {
    const inviteUrl = "https://example.com/invite"; // Your invite URL

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.blue.shade50,
          title: const Text("Invite Friends"),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Share the following link to invite friends:",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              SelectableText(inviteUrl),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: inviteUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Link copied to clipboard")),
                );
                Navigator.of(context).pop();
              },
              child: const Text(
                "Copy Link",
                style: TextStyle(color: Colors.blue),
              ),
            ),
            TextButton(
              onPressed: () async {
                if (await canLaunch(inviteUrl)) {
                  await launch(inviteUrl);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Could not launch URL")),
                  );
                }
                Navigator.of(context).pop();
              },
              child: const Text(
                "Open Link",
                style: TextStyle(color: Colors.blue),
              ),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade200,
            Colors.blue.shade800,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Invite friends',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              // Handle back button action

              Navigator.pop(context);
            },
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header section
              Container(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 5),
                    Image.asset(
                      'assets/images/invite.png',
                      height: 250,
                      fit: BoxFit.cover,
                    ),
                  ],
                ),
              ),
              // Reward rules section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Reward rules',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const RewardRuleItem(
                      step: 1,
                      description: 'Invite 1 friend',
                      reward: 'Get 5000 Coins',
                    ),
                    const RewardRuleItem(
                      step: 2,
                      description: "Friend's first recharge",
                      reward: 'Get 5000 Coins',
                    ),
                    const RewardRuleItem(
                      step: 3,
                      description: 'Friends send gifts',
                      reward: 'Get 5% Coins',
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          _showInviteDialog(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 32),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Invite friends to get ',
                              style:
                                  TextStyle(color: Colors.blue, fontSize: 20),
                            ),
                            Icon(Icons.diamond, color: Colors.blue),
                            // Text(
                            //   ' Diamonds',
                            //   style: TextStyle(color: Colors.white, fontSize: 20),
                            // ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RewardRuleItem extends StatelessWidget {
  final int step;
  final String description;
  final String reward;

  const RewardRuleItem({
    super.key,
    required this.step,
    required this.description,
    required this.reward,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue,
            child: Text(
              step.toString(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  reward,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.blue),
        ],
      ),
    );
  }
}
