import 'package:badges/badges.dart' as badges;
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:memolanes/body/settings/advanced_settings_page.dart';
import 'package:memolanes/body/settings/import_data_page.dart';
import 'package:memolanes/body/settings/map_settings_page.dart';
import 'package:memolanes/common/component/basic_bottom_sheet.dart';
import 'package:memolanes/common/component/common_export.dart';
import 'package:memolanes/common/component/scroll_views/single_child_scroll_view.dart';
import 'package:memolanes/common/component/tiles/label_tile.dart';
import 'package:memolanes/common/component/tiles/label_tile_content.dart';
import 'package:memolanes/common/component/tiles/label_tile_title.dart';
import 'package:memolanes/common/gps_manager.dart';
import 'package:memolanes/common/mmkv_util.dart';
import 'package:memolanes/common/update_notifier.dart';
import 'package:memolanes/common/utils.dart';
import 'package:memolanes/constants/style_constants.dart';
import 'package:memolanes/src/rust/api/api.dart' as api;
import 'package:memolanes/utils/nav_helper.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'contact_us_page.dart';

class SettingsBody extends StatefulWidget {
  const SettingsBody({super.key});

  @override
  State<SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<SettingsBody> {
  bool _isUnexpectedExitNotificationEnabled = false;
  String _version = "";

  @override
  void initState() {
    super.initState();
    _loadNotificationStatus();
    _loadVersion();
  }

  void _loadVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version =
          '${packageInfo.version} (${packageInfo.buildNumber}) [${api.shortCommitHash()}]';
    });
  }

  void _launchUrl(String updateUrl) async {
    final url = Uri.parse(updateUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $updateUrl';
    }
  }

  Future<void> _selectImportFile(
    BuildContext context,
    ImportType importType,
  ) async {
    // TODO: FilePicker is weird and `allowedExtensions` does not really work.
    // https://github.com/miguelpruivo/flutter_file_picker/wiki/FAQ
    // List<String> allowedExtensions;
    // if (importType == ImportType.fow) {
    //   allowedExtensions = ['zip'];
    // } else {
    //   allowedExtensions = ['kml', 'gpx', 'csv'];
    // }
    final result = await FilePicker.pickFiles(type: FileType.any);
    final path = result?.files.single.path;
    if (path != null && context.mounted) {
      navigatorPush(
        context,
        page: ImportDataPage(path: path, importType: importType),
      );
    }
  }

  Future<void> _loadNotificationStatus() async {
    setState(() {
      _isUnexpectedExitNotificationEnabled = MMKVUtil.getBool(
          MMKVKey.isUnexpectedExitNotificationEnabled,
          defaultValue: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    var updateUrl = context.watch<UpdateNotifier>().updateUrl;
    var gpsManager = context.watch<GpsManager>();

    return MlSingleChildScrollView(
      padding: EdgeInsets.only(
        top: 16.0,
        bottom: StyleConstants.navBarSafeArea + 16.0,
      ),
      children: [
        const _SettingsPageHeader(),
        const SizedBox(height: 18),
        // TODO: Enable this when we have user system.
        // CircleAvatar(
        //   backgroundColor: const Color(0xFFB6E13D),
        //   radius: 45.0,
        // ),
        // Padding(
        //   padding: EdgeInsets.symmetric(vertical: 16.0),
        //   child: Text(
        //     'Foo Bar',
        //     style: TextStyle(
        //       fontSize: 24.0,
        //       color: const Color(0xFFFFFFFF),
        //     ),
        //   ),
        // ),
        LabelTileTitle(
          label: context.tr("general.title"),
        ),
        LabelTile(
          label: context.tr("general.version.title"),
          position: LabelTilePosition.middle,
          prefix: const _SettingsTileIcon(
            icon: Icons.info_outline_rounded,
            yellow: true,
          ),
          trailing: updateUrl != null
              ? badges.Badge(
                  badgeStyle: badges.BadgeStyle(
                    shape: badges.BadgeShape.square,
                    borderRadius: BorderRadius.circular(5),
                    padding: const EdgeInsets.all(2),
                    badgeGradient: const badges.BadgeGradient.linear(
                      colors: [
                        StyleConstants.primaryGreen,
                        StyleConstants.journeyYellow,
                        StyleConstants.primaryGreen,
                      ],
                    ),
                  ),
                  badgeContent: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: LabelTileContent(
                    content: _version,
                  ),
                )
              : LabelTileContent(
                  content: _version,
                ),
          onTap: () async {
            if (updateUrl != null) {
              _launchUrl(updateUrl);
              return;
            }
            await showCommonDialog(
              context,
              context.tr("general.version.currently_the_latest_version"),
            );
          },
        ),
        LabelTile(
          label: context.tr("general.map_settings.title"),
          position: LabelTilePosition.middle,
          prefix: const _SettingsTileIcon(icon: Icons.map_outlined),
          trailing: LabelTileContent(showArrow: true),
          onTap: () => navigatorPush(context, page: const MapSettingsPage()),
        ),
        LabelTile(
          label: context.tr("general.advanced_settings.title"),
          position: LabelTilePosition.bottom,
          prefix: const _SettingsTileIcon(icon: Icons.tune_rounded),
          trailing: LabelTileContent(showArrow: true),
          onTap: () => navigatorPush(context, page: AdvancedSettingsPage()),
        ),
        LabelTileTitle(
          label: context.tr("data.title"),
        ),
        // TODO: This is unused, but we may use it depending on the design of
        // import/export workflow.
        //
        // LabelTile(
        //   label: context.tr("data.backup_data.title"),
        //   position: LabelTilePosition.middle,
        //   trailing: LabelTileContent(showArrow: true),
        //   onTap: () => Navigator.push(
        //     context,
        //     MaterialPageRoute(
        //       builder: (context) {
        //         return BackupDataScreen();
        //       },
        //     ),
        //   ),
        // ),
        LabelTile(
          label: context.tr("data.import_data.title"),
          position: LabelTilePosition.middle,
          prefix: const _SettingsTileIcon(
            icon: Icons.file_download_outlined,
          ),
          trailing: LabelTileContent(showArrow: true),
          onTap: () => _showImportDataCard(context),
        ),
        LabelTile(
          label: context.tr("data.export_data.export_all"),
          position: LabelTilePosition.bottom,
          prefix: const _SettingsTileIcon(
            icon: Icons.file_upload_outlined,
            yellow: true,
          ),
          onTap: () async {
            if (gpsManager.recordingStatus != GpsRecordingStatus.none) {
              await showCommonDialog(
                context,
                context.tr("journey.stop_ongoing_journey"),
              );
              return;
            }
            final hasJourneys = await api.hasJourneys();
            if (!context.mounted) return;
            if (!hasJourneys) {
              await showCommonDialog(
                context,
                context.tr("data.export_data.error.no_journeys_to_export"),
              );
              return;
            }
            await showCommonExportWithFormatPicker(
              context: context,
              title: context.tr("data.export_data.export_all_title"),
              formats: const [
                CommonExportFormat.mldx,
                CommonExportFormat.fwss,
              ],
              exportFile: (format) async {
                var tmpDir = await getTemporaryDirectory();
                final now = DateTime.now();
                final timestamp = DateFormat('yyyy-MM-dd-HH-mm-ss').format(now);
                final filepath =
                    "${tmpDir.path}/all-journeys-$timestamp.${format.extension}";
                final exportResult = switch (format) {
                  CommonExportFormat.mldx =>
                    await api.generateFullArchive(targetFilepath: filepath),
                  CommonExportFormat.fwss =>
                    await api.exportAllJourneysAsFwss(targetFilepath: filepath),
                  CommonExportFormat.kml ||
                  CommonExportFormat.gpx =>
                    throw UnsupportedError(
                        'Unsupported export format: $format'),
                };
                return CommonExportResult.create(exportResult, filepath);
              },
            );
          },
        ),
        LabelTileTitle(
          label: context.tr("settings.other"),
        ),
        LabelTile(
          label: context.tr("unexpected_exit_notification.setting_title"),
          position: LabelTilePosition.bottom,
          prefix: const _SettingsTileIcon(
            icon: Icons.notifications_active_outlined,
            yellow: true,
          ),
          trailing: Switch(
            value: _isUnexpectedExitNotificationEnabled,
            onChanged: (value) async {
              final status = await Permission.notification.status;
              if (value) {
                if (!status.isGranted) {
                  setState(() {
                    _isUnexpectedExitNotificationEnabled = false;
                  });

                  if (!context.mounted) return;
                  await showCommonDialog(
                    context,
                    context.tr(
                        "unexpected_exit_notification.notification_permission_denied"),
                  );
                  Geolocator.openAppSettings();
                  return;
                }
              }
              MMKVUtil.putBool(
                  MMKVKey.isUnexpectedExitNotificationEnabled, value);
              setState(() {
                _isUnexpectedExitNotificationEnabled = value;
              });
              if (gpsManager.recordingStatus == GpsRecordingStatus.recording) {
                if (!context.mounted) return;
                await showCommonDialog(
                    context,
                    context.tr(
                      "unexpected_exit_notification.change_affect_next_time",
                    ));
              }
            },
          ),
        ),
        LabelTileTitle(
          label: context.tr("settings.about"),
        ),
        LabelTile(
          label: context.tr("privacy.name"),
          position: LabelTilePosition.middle,
          prefix: const _SettingsTileIcon(icon: Icons.shield_outlined),
          trailing: LabelTileContent(rightIcon: Icons.open_in_new),
          onTap: () async {
            await launchUrlString(context.tr("privacy.url"),
                mode: LaunchMode.externalApplication);
          },
        ),
        LabelTile(
          label: context.tr("contact_us.title"),
          position: LabelTilePosition.bottom,
          prefix: const _SettingsTileIcon(
            icon: Icons.forum_outlined,
            yellow: true,
          ),
          trailing: LabelTileContent(rightIcon: Icons.arrow_forward_ios),
          onTap: () => navigatorPush(context, page: ContactUsPage()),
        ),
      ],
    );
  }

  void _showImportDataCard(BuildContext context) {
    showBasicBottomSheet<void>(
      context,
      title: context.tr("data.import_data.title"),
      leading: const _ImportDataHeaderIcon(),
      maxHeightFactor: 0.68,
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr("data.import_data.description"),
            style: const TextStyle(
              color: StyleConstants.mutedInkColor,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: StyleConstants.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: StyleConstants.lineColor),
              boxShadow: [
                BoxShadow(
                  color: StyleConstants.inkColor.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                _ImportDataOption(
                  icon: Icons.inventory_2_outlined,
                  label: context.tr("journey.import_mldx_data"),
                  onTap: () async {
                    // TODO: FilePicker is weird and `allowedExtensions` does not really work.
                    // https://github.com/miguelpruivo/flutter_file_picker/wiki/FAQ
                    var result = await FilePicker.pickFiles(
                      type: FileType.any,
                    );
                    if (!context.mounted) return;
                    if (result != null) {
                      var path = result.files.single.path;
                      if (path != null) {
                        await importMldx(context, path);
                      }
                    }
                  },
                ),
                const _ImportDataDivider(),
                _ImportDataOption(
                  icon: Icons.route_outlined,
                  label: context.tr("journey.import_track_file"),
                  onTap: () async {
                    await showCommonDialog(
                      context,
                      context.tr("import.import_track_file.description_md"),
                      markdown: true,
                    );
                    if (!context.mounted) return;
                    await _selectImportFile(context, ImportType.vector);
                  },
                ),
                const _ImportDataDivider(),
                _ImportDataOption(
                  icon: Icons.grid_4x4_outlined,
                  label: context.tr("journey.import_fog_of_world_data"),
                  onTap: () async {
                    await showCommonDialog(
                      context,
                      context.tr("import.import_fow_data.description_md"),
                      markdown: true,
                    );
                    if (await api.containsBitmapJourney()) {
                      if (!context.mounted) return;
                      await showCommonDialog(
                        context,
                        context.tr(
                          "import.import_fow_data.warning_for_import_multiple_data_md",
                        ),
                        markdown: true,
                      );
                    }
                    if (!context.mounted) return;
                    await _selectImportFile(context, ImportType.fow);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportDataHeaderIcon extends StatelessWidget {
  const _ImportDataHeaderIcon();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: StyleConstants.softGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.file_download_outlined,
          color: StyleConstants.deepGreen,
          size: 21,
        ),
      ),
    );
  }
}

class _ImportDataOption extends StatelessWidget {
  const _ImportDataOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: StyleConstants.softGreen,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: StyleConstants.deepGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: StyleConstants.inkColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: StyleConstants.mutedInkColor,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportDataDivider extends StatelessWidget {
  const _ImportDataDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 64),
      child: Divider(
        height: 1,
        thickness: 1,
        color: StyleConstants.lineColor,
      ),
    );
  }
}

class _SettingsTileIcon extends StatelessWidget {
  const _SettingsTileIcon({
    required this.icon,
    this.yellow = false,
  });

  final IconData icon;
  final bool yellow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: yellow ? StyleConstants.softYellow : StyleConstants.softGreen,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 17,
          color: yellow ? StyleConstants.deepYellow : StyleConstants.deepGreen,
        ),
      ),
    );
  }
}

class _SettingsPageHeader extends StatelessWidget {
  const _SettingsPageHeader();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('settings.page_title'),
            style: const TextStyle(
              color: StyleConstants.inkColor,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            context.tr('settings.page_subtitle'),
            style: const TextStyle(
              color: StyleConstants.mutedInkColor,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
