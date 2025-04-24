import 'package:flutter/material.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  bool isTapped = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Language Page'),
          centerTitle: true,
          backgroundColor: Colors.white,
          actions: [
            IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.check,
                  size: 30,
                ))
          ],
        ),
        body: Column(
          children: [
            const Divider(),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    isTapped = !isTapped;
                  });
                },
                child: SizedBox(
                  height: 50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('English', style: TextStyle(fontSize: 20)),
                      CircleAvatar(
                          radius: 15,
                          backgroundColor:
                              isTapped ? Colors.blue[600] : Colors.grey[300],
                          child: isTapped
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.black,
                                )
                              : null),
                    ],
                  ),
                ),
              ),
            ),
            const Divider()
          ],
        ));
  }
}
