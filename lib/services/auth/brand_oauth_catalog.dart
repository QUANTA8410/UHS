import 'package:flutter/material.dart';

class BrandAuthProviderConfig {
  final String id;
  final String brandName;
  final String subtitle;
  final Color brandColor;
  final IconData icon;
  final String loginUrl;
  final String redirectUriPrefix;
  final String tokenExchangeUrl;
  final String vendorType; // 'smartthings', 'lg_thinq', 'wipro_tuya', 'home_assistant'
  final String? authFlowLabel;

  const BrandAuthProviderConfig({
    required this.id,
    required this.brandName,
    required this.subtitle,
    required this.brandColor,
    required this.icon,
    required this.loginUrl,
    required this.redirectUriPrefix,
    this.tokenExchangeUrl = '',
    required this.vendorType,
    this.authFlowLabel,
  });
}

class BrandOAuthCatalog {
  static const List<BrandAuthProviderConfig> providers = [
    BrandAuthProviderConfig(
      id: 'samsung_smartthings',
      brandName: 'Samsung SmartThings',
      subtitle: 'Sign in with Samsung Account (Washers, ACs, TVs, Tags)',
      brandColor: Color(0xFF1428A0),
      icon: Icons.local_laundry_service_rounded,
      loginUrl: 'https://account.smartthings.com/tokens',
      redirectUriPrefix: 'unifiedhome://oauth/smartthings',
      tokenExchangeUrl: 'https://api.smartthings.com/oauth/token',
      vendorType: 'smartthings',
    ),
    BrandAuthProviderConfig(
      id: 'lg_thinq',
      brandName: 'LG ThinQ',
      subtitle: 'Sign in with LG Account (DualCool AC, Washers, Fridges, webOS)',
      brandColor: Color(0xFFA50034),
      icon: Icons.ac_unit_rounded,
      loginUrl: 'https://connect-pat.lgthinq.com/',
      redirectUriPrefix: 'unifiedhome://oauth/lgthinq',
      vendorType: 'lg_thinq',
    ),
    BrandAuthProviderConfig(
      id: 'wipro_smart_next',
      brandName: 'Wipro Next Smart Home',
      subtitle: 'Out-of-App Official Wipro Next Login & LAN Auto-Link (Port 6668)',
      brandColor: Color(0xFF0052CC),
      icon: Icons.lightbulb_rounded,
      loginUrl: 'https://www.wiproconsumerlighting.com/login',
      redirectUriPrefix: 'unifiedhome://oauth/tuya',
      vendorType: 'wipro_tuya',
      authFlowLabel: 'Out-of-App Official Wipro Next Login & LAN Auto-Link',
    ),
    BrandAuthProviderConfig(
      id: 'philips_hue',
      brandName: 'Philips Hue',
      subtitle: 'Auto-Discovery & 1-Tap Physical Pushlink Bridge Pairing',
      brandColor: Color(0xFF0066CC),
      icon: Icons.wb_incandescent_rounded,
      loginUrl: 'https://api.meethue.com/v2/oauth2/authorize?client_id=unified_home&response_type=code',
      redirectUriPrefix: 'unifiedhome://oauth/hue',
      tokenExchangeUrl: 'https://api.meethue.com/v2/oauth2/token',
      vendorType: 'philips_hue',
    ),
    BrandAuthProviderConfig(
      id: 'philips_wiz',
      brandName: 'Philips WiZ',
      subtitle: 'Local Wi-Fi UDP Port 38899 Discovery & Direct Offline Control',
      brandColor: Color(0xFF6B38FB),
      icon: Icons.lightbulb_outline_rounded,
      loginUrl: 'https://www.wizconnected.com',
      redirectUriPrefix: 'unifiedhome://oauth/wiz',
      vendorType: 'philips_wiz',
    ),
    BrandAuthProviderConfig(
      id: 'realme_camera',
      brandName: 'Realme Smart Cam 360',
      subtitle: 'High-Speed RTSP/ONVIF Stream with PTZ Pan-Tilt Controls',
      brandColor: Color(0xFFFFB800),
      icon: Icons.videocam_rounded,
      loginUrl: 'https://www.realme.com',
      redirectUriPrefix: 'unifiedhome://camera/realme',
      vendorType: 'realme_camera',
    ),
    BrandAuthProviderConfig(
      id: 'philips_camera',
      brandName: 'Philips Home Camera',
      subtitle: 'RTSP 1080p Live Stream & Privacy Mode Monitoring',
      brandColor: Color(0xFF0066CC),
      icon: Icons.security_rounded,
      loginUrl: 'https://www.philips.com',
      redirectUriPrefix: 'unifiedhome://camera/philips',
      vendorType: 'philips_camera',
    ),
    BrandAuthProviderConfig(
      id: 'tplink_tapo',
      brandName: 'TP-Link Tapo / Kasa',
      subtitle: 'Sign in with TP-Link ID',
      brandColor: Color(0xFF4ACBD6),
      icon: Icons.power_rounded,
      loginUrl: 'https://www.tapo.com/en/login/',
      redirectUriPrefix: 'unifiedhome://oauth/tapo',
      vendorType: 'tplink_tapo',
    ),
    BrandAuthProviderConfig(
      id: 'home_assistant',
      brandName: 'Home Assistant / Universal Matter Bridge',
      subtitle: 'Sign in to your local Home Assistant OAuth2 server',
      brandColor: Color(0xFF03A9F4),
      icon: Icons.hub_rounded,
      loginUrl: 'http://homeassistant.local:8123/auth/authorize?response_type=code&client_id=https://unifiedhome.local&redirect_uri=unifiedhome://oauth/ha',
      redirectUriPrefix: 'unifiedhome://oauth/ha',
      vendorType: 'home_assistant',
    ),
  ];
}
