import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:leo_app_01/level/progressbar.dart';
import 'package:leo_app_01/level/question.dart';
import 'package:leo_app_01/level/statemanegemnt/fillcount.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:provider/provider.dart';

class RankingPagelevel extends StatefulWidget {
  String ID;
  RankingPagelevel({required this.ID, super.key});

  @override
  State<RankingPagelevel> createState() => _RankingPagelevelState();
}

class _RankingPagelevelState extends State<RankingPagelevel> {
  String backgroundimage = "assetss/images/Bronze NO UI copy.jpg";
  String frame =
      'http://145.223.21.62:8090/api/files/vnhwix61fv2fpio/585esvwsyw2u53n/bframe_AJRKcd5iAi.png?token=';
  String legacy =
      "http://145.223.21.62:8090/api/files/vnhwix61fv2fpio/butw0x7a2kuw8gd/bronze_rhZJjww6V0.png?token=";
  String how = 'assetss/images/bronzehow.png';
  String badge = 'assetss/images/br0.png';
  String rewards = "assetss/images/bronzereward.png";
  Color middleborder = const Color.fromARGB(255, 203, 139, 108);
  Color downborder = const Color.fromARGB(255, 120, 75, 63);
  Color first = const Color.fromARGB(255, 203, 139, 108);
  Color second = const Color.fromARGB(255, 193, 123, 91);
  final PocketBase pb = PocketBase('http://145.223.21.62:8090');
  List<String> imageUrls = []; // To hold the list of image URLs
  bool isLoading = true; // To show loading state
  String errorMessage = '';
  String profilepic = '';
  final idFromOtherPage = "abc123"; // Replace with the actual ID you receive

  Future<void> fetchAndUpdateNobelCount() async {
    try {
      // Fetch user information
      final user = await pb.collection('users').getFirstListItem(
            'id="${widget.ID}"',
          );
      final avatar = user.data['avatar'].toString();

      // Construct the full URL if avatar is not empty
      if (avatar.isNotEmpty) {
        profilepic = '${pb.baseUrl}/api/files/users/${user.id}/$avatar';
      } else {
        profilepic = ''; // Handle case where no avatar exists
      }

      print('User Avatar URL: $profilepic');

      // Fetch all records for the user in the level_Timer collection (if needed)
      // ...
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  Future<void> fetchAndAddImageUrls(String userId) async {
    try {
      // Fetch the image URLs
      final urls = await fetchImageUrls(userId);
      if (mounted) {
        setState(() {
          imageUrls = urls; // Add to the list
          isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load images: $error';
          isLoading = false;
        });
      }
    }
  }

  Future<List<String>> fetchImageUrls(String userId) async {
    try {
      final records = await pb.collection('images').getFullList(
            filter: 'id="$userId"',
          );
      if (records.isEmpty) {
        print('No records found for userId=$userId');
        return [];
      }
      List<String> imageUrls = [];
      for (var record in records) {
        List<dynamic> files = record.data['field'] ?? [];
        for (var file in files) {
          final url = pb.getFileUrl(record, file).toString();
          imageUrls.add(url);
        }
      }

      return imageUrls;
    } catch (error) {
      print('Error fetching images: $error');
      return [];
    }
  }

  String generateFixedLengthId(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  Future<void> sendTextToPrivilegeCollection(
      final timemin, String specificId) async {
    String nameitem;
    final fillcount = fillCount.fillCount;

    if (specificId.length != 15) {
      print('Error: The provided ID must be exactly 15 characters long.');
      return;
    }

    // Determine the nameitem based on nobelcount
    if (timemin >= 0 && timemin < 210) {
      nameitem = "Bronve";
    } else if (timemin >= 210 && timemin < 810) {
      nameitem = "Silver";
    } else if (timemin >= 810 && timemin < 2100) {
      nameitem = "Gold";
    } else if (timemin >= 2100 && timemin < 4650) {
      nameitem = "Platinum";
    } else if (timemin >= 4650) {
      nameitem = "Diamond";
    } else {
      print('Nobel count does not match any range.');
      return;
    }

    try {
      // Check if the specific ID exists
      final existingEntry =
          await pb.collection('recieved_badges').getOne(specificId);

      // Update the existing record
      final updatedEntry = {
        'batch_name': "${nameitem} level $fillcount",
        'userId': widget.ID,
      };

      await pb
          .collection('recieved_badges')
          .update(specificId, body: updatedEntry);
      print('Updated existing entry in received_badges: $updatedEntry');
    } catch (error) {
      // Handle the case where the record doesn't exist (404)
      if (error.toString().contains("404")) {
        print('Record not found, creating a new entry.');

        final newEntry = {
          'batch_name': "${nameitem} level $fillcount",
          'userId': widget.ID,
          'id': specificId, // Use the same specific ID
        };

        await pb.collection('recieved_badges').create(body: newEntry);
        print('Created new entry in received_badges: $newEntry');
      } else {
        print('Error updating or creating entry in received_badges: $error');
      }
    }
  }

  void getting(final fillingcount, final timemin) async {
    // Check if the imageUrls list is empty, and if so, fetch the images.
    if (imageUrls.isEmpty) {
      // Wait for the images to be fetched before proceeding
      await fetchAndAddImageUrls("a5rkdnty7bobzil");
    }

    // Now safely access the imageUrls list
    if (timemin >= 0 && timemin < 210) {
      backgroundimage = "assetss/images/Bronze NO UI copy.jpg";
      frame =
          'http://145.223.21.62:8090/api/files/vnhwix61fv2fpio/585esvwsyw2u53n/bframe_AJRKcd5iAi.png?token=';
      legacy =
          "http://145.223.21.62:8090/api/files/vnhwix61fv2fpio/butw0x7a2kuw8gd/bronze_rhZJjww6V0.png?token=";
      how = 'assetss/images/bronzehow.png';
      badge = imageUrls.isNotEmpty
          ? imageUrls[fillingcount]
          : 'http://145.223.21.62:8090/api/files/vnhwix61fv2fpio/a5rkdnty7bobzil/br0_JOVckwzdAz.png?token='; // Safe access
      rewards = "assetss/images/bronzereward.png";
      middleborder = const Color.fromARGB(255, 203, 139, 108);
      downborder = const Color.fromARGB(255, 120, 75, 63);
      first = const Color.fromARGB(255, 203, 139, 108);
      second = const Color.fromARGB(255, 193, 123, 91);
    } else if (timemin >= 210 && timemin < 810) {
      await fetchAndAddImageUrls("9knou40t8xgcu49");
      backgroundimage = "assetss/images/Silver NO UI copy.jpg";
      frame =
          'http://145.223.21.62:8090/api/files/vnhwix61fv2fpio/585esvwsyw2u53n/sframe_cwENVGvfMl.png?token=';
      legacy =
          'http://145.223.21.62:8090/api/files/vnhwix61fv2fpio/butw0x7a2kuw8gd/silver_Pz8UaLptW9.png?token=';
      how = 'assetss/images/silverhow.png';
      badge = imageUrls.isNotEmpty
          ? imageUrls[fillingcount]
          : 'http://145.223.21.62:8090/api/files/vnhwix61fv2fpio/a5rkdnty7bobzil/br0_JOVckwzdAz.png?token='; // Safe access
      rewards = "assetss/images/silverreward.png";
      middleborder = Color.fromARGB(255, 186, 221, 230);
      downborder = const Color.fromARGB(255, 106, 137, 155);
      first = const Color.fromARGB(255, 181, 216, 225);
      second = const Color.fromARGB(255, 125, 157, 173);
      print(badge);
    } else if (timemin >= 810 && timemin < 2100) {
      await fetchAndAddImageUrls("xxbuxvnt9afq1y4");
      backgroundimage = "assetss/images/Gold NO UI copy.jpg";
      frame =
          'http://145.223.21.62:8090/api/files/vnhwix61fv2fpio/585esvwsyw2u53n/gframe_rzuqY4FrJ2.png?token=';
      legacy =
          'http://145.223.21.62:8090/api/files/vnhwix61fv2fpio/butw0x7a2kuw8gd/gold_i5wi6ZVrI6.png?token=';
      how = 'assetss/images/goldhow.png';
      badge = imageUrls.isNotEmpty
          ? imageUrls[fillingcount]
          : 'http://145.223.21.62:8090/api/files/vnhwix61fv2fpio/a5rkdnty7bobzil/br0_JOVckwzdAz.png?token='; // Safe access
      rewards = "assetss/images/goldreward.png";
      middleborder = Color.fromARGB(255, 234, 209, 123);
      downborder = const Color.fromARGB(255, 219, 155, 60);
      first = const Color.fromARGB(255, 233, 207, 120);
      second = const Color.fromARGB(255, 222, 167, 74);
    } else if (timemin >= 2100 && timemin < 4650) {
      await fetchAndAddImageUrls("l2z2sjy2c9djo0o");
      backgroundimage = "assetss/images/Platinum NO UI copy.jpg";
      frame =
          'http://145.223.21.62:8090/api/files/vnhwix61fv2fpio/585esvwsyw2u53n/pframe_JUI9lvwSEo.png?token=';
      legacy =
          'http://145.223.21.62:8090/api/files/vnhwix61fv2fpio/butw0x7a2kuw8gd/platinum_IlpEQ1SpSS.png?token=';
      how = 'assetss/images/platinumhow.png';
      badge = imageUrls.isNotEmpty
          ? imageUrls[fillingcount]
          : 'http://145.223.21.62:8090/api/files/vnhwix61fv2fpio/a5rkdnty7bobzil/br0_JOVckwzdAz.png?token='; // Safe access
      rewards = "assetss/images/platinumreward.png";
      middleborder = Color.fromARGB(255, 208, 198, 166);
      downborder = const Color.fromARGB(255, 149, 139, 105);
      first = const Color.fromARGB(255, 204, 194, 162);
      second = const Color.fromARGB(255, 156, 146, 112);
    } else if (timemin >= 4650) {
      await fetchAndAddImageUrls("fvwi1h25xvjvsfh");
      backgroundimage = "assetss/images/Diamond NO UI copy.jpg";
      frame =
          'http://145.223.21.62:8090/api/files/vnhwix61fv2fpio/585esvwsyw2u53n/dframe_O3HPn1K2Jb.png?token=';
      legacy =
          'http://145.223.21.62:8090/api/files/vnhwix61fv2fpio/butw0x7a2kuw8gd/diamond_9yvM3gxc8L.png?token=';
      how = 'assetss/images/how.png';
      badge = imageUrls.isNotEmpty
          ? imageUrls[fillingcount]
          : 'http://145.223.21.62:8090/api/files/vnhwix61fv2fpio/a5rkdnty7bobzil/br0_JOVckwzdAz.png?token='; // Safe access
      rewards = "assetss/images/reward.png";
      middleborder = Color.fromARGB(255, 188, 171, 216);
      downborder = const Color.fromARGB(255, 94, 92, 136);
      first = const Color.fromARGB(255, 188, 172, 216);
      second = const Color.fromARGB(255, 151, 144, 210);
    }
    sendTextToPrivilegeCollection(timemin, "123456789012345");
  }

  late Timer _timer;

  @override
  void initState() {
    super.initState();
    // Set up a timer to refresh the page every 2 seconds
    _timer = Timer.periodic(Duration(seconds: 2), (Timer timer) {
      setState(() {}); // Trigger a rebuild
    });
    fetchAndUpdateNobelCount();
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fillcount = fillCount.fillCount;
    final timemin = fillCount.fetchedMinutes;
    final want = fillCount.want;

    print("fill count  $fillcount");

    getting(fillcount, timemin);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(backgroundimage),
                fit: BoxFit.cover,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding:
                          EdgeInsets.only(top: height / 60, left: width / 30),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                        child: Icon(
                          Icons.arrow_back_ios,
                          size: width / 25,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Padding(
                      padding:
                          EdgeInsets.only(top: height / 60, right: width / 30),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) {
                              return questionlevel();
                            },
                          ));
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(5.0),
                            child: Center(
                              child: Icon(
                                Icons.question_mark,
                                size: width / 25,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  height: height / 3.3,
                  width: width,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          // DFrame image container
                          Positioned(
                            top: height / 35,
                            left: width / 25,
                            child: Container(
                              height: height / 10,
                              width: height / 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: NetworkImage(profilepic),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            height: height / 7,
                            width: height / 7,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              image: DecorationImage(
                                alignment: Alignment.topCenter,
                                image: NetworkImage(frame),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          // User image container
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          left: width / 3.5,
                          right: width / 3.5,
                          top: height / 200,
                        ),
                        child: Container(
                          width: width,
                          height: height / 17,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomLeft,
                              end: Alignment.bottomRight,
                              colors: [first, second],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: downborder,
                              width: 5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(left: width / 30),
                                child: Text(
                                  "LEVEL $fillcount",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: height / 40,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                              Container(
                                height: height / 50,
                                width: width / 10,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: downborder,
                                    width: 3,
                                  ),
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        height: height / 200,
                      ),
                      ProgressBar(
                        ID: widget.ID.toString(),
                      ),
                      // Adding the text below the ProgressBar
                      Padding(
                        padding: EdgeInsets.only(top: height / 100),
                        child: Text(
                          "You need $want Min for next level",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: height / 65,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: width / 7,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                image: DecorationImage(
                                  image: AssetImage(rewards),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: middleborder,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  offset: Offset(0, 5),
                                  blurRadius: 5,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        image: DecorationImage(
                                          image: NetworkImage(badge),
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      image: DecorationImage(
                                        image: NetworkImage(legacy),
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                        vertical: height / 20),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        image: DecorationImage(
                                          image: NetworkImage(frame),
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding:
                                EdgeInsets.symmetric(vertical: height / 50),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: SizedBox(
                                    child: Image.asset(
                                      how,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    child: SingleChildScrollView(
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                            left: 30, right: 30),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "• The longer the login duration,\n  the higher the level.",
                                              style: TextStyle(
                                                  decoration:
                                                      TextDecoration.none,
                                                  color: Colors.black,
                                                  fontSize: height / 50),
                                            ),
                                            SizedBox(
                                              height: height / 40,
                                            ),
                                            Text(
                                                "• The higher the level, the more\n  popular you are in Leo.",
                                                style: TextStyle(
                                                    decoration:
                                                        TextDecoration.none,
                                                    color: Colors.black,
                                                    fontSize: height / 50)),
                                            SizedBox(
                                              height: height / 40,
                                            ),
                                            Text("• Speak in the group",
                                                style: TextStyle(
                                                    decoration:
                                                        TextDecoration.none,
                                                    color: Colors.black,
                                                    fontSize: height / 50)),
                                            SizedBox(
                                              height: height / 40,
                                            ),
                                            Text(
                                                "• Group=00 Exp,up to 5.00 Exp per day",
                                                style: TextStyle(
                                                    decoration:
                                                        TextDecoration.none,
                                                    color: Colors.black,
                                                    fontSize: height / 50)),
                                            SizedBox(
                                              height: height / 40,
                                            ),
                                            Text(
                                                "• Click the button if you want to know\n  more",
                                                style: TextStyle(
                                                    decoration:
                                                        TextDecoration.none,
                                                    color: Colors.black,
                                                    fontSize: height / 50)),
                                            SizedBox(
                                              height: height / 60,
                                            ),
                                            ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        middleborder),
                                                onPressed: () {
                                                  Navigator.of(context)
                                                      .push(MaterialPageRoute(
                                                    builder: (context) {
                                                      return questionlevel();
                                                    },
                                                  ));
                                                },
                                                child: Text(
                                                  "GO",
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: height / 50),
                                                ))
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
