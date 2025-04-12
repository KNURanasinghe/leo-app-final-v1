import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:leo_app_01/services/socket_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../HomeScreen.dart';
import 'chatting.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
part 'new_peer_chat_dialog.dart';
