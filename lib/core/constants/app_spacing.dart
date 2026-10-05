/// Spacing on an 8-point grid (4 for fine adjustments), shared by the customer
/// and admin apps (Enhancement Spec §4). The short names are the spec tokens;
/// change a token here and both apps stay consistent.
class AppSpacing {
  // ===== Spec §4 tokens =====
  static const double xs = 4; // icon-to-text gap
  static const double sm = 8; // inside chips, label-to-field
  static const double md = 12; // between list items, inside small cards
  static const double lg = 16; // card padding, between fields
  static const double xl = 20; // screen side margin (mobile)
  static const double xxl = 24; // between sections
  static const double xxxl = 32; // top of screen, around hero blocks

  // Older descriptive names (kept for existing code)
  static const double baseUnit = 8.0;
  static const double micro = xs;
  static const double tiny = sm;
  static const double small = md;
  static const double medium = lg;
  static const double large = xxl;
  static const double extraLarge = xxxl;
  static const double extraExtraLarge = 40.0;

  // Huge spacing (48px) - major separators
  static const double huge = 48.0;

  // Screen Padding
  static const double screenPaddingHorizontal = 20.0;
  static const double screenPaddingVertical = 16.0;

  // Card Padding
  static const double cardPaddingHorizontal = 16.0;
  static const double cardPaddingVertical = 16.0;

  // List Item Spacing
  static const double listItemSpacing = 12.0;
  static const double listItemPadding = 16.0;

  // Form Spacing
  static const double formFieldSpacing = 16.0;
  static const double formSectionSpacing = 24.0;

  // Button Spacing
  static const double buttonPaddingHorizontal = 24.0;
  static const double buttonPaddingVertical = 12.0;
  static const double buttonIconGap = 8.0;

  // Icon Spacing
  static const double iconTextGap = 8.0;
  static const double iconSmallGap = 6.0;

  // Border Radius
  static const double radiusSmall = 6.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 14.0;
  static const double radiusExtraLarge = 20.0;
  static const double radiusFull = 999.0; // Fully rounded

  // Card Border Radius
  static const double cardRadius = 20.0; // Rounded, friendly cards (spec §4.5)
  static const double cardRadiusSmall = 12.0; // spec §4: small cards 12

  // Button Border Radius
  static const double buttonRadius = 999.0; // Pill/oval buttons (spec §4.4)
  static const double buttonRadiusSmall = 999.0;

  // Badge Border Radius
  static const double badgeRadius = 999.0;

  // Input Border Radius
  static const double inputRadius = 12.0; // spec §4: fields 12

  // Modal Border Radius
  static const double modalRadius = 20.0; // spec §4: sheets 20

  // Bottom Sheet Border Radius
  static const double bottomSheetRadius = 20.0;

  // Icon Sizes
  static const double iconSizeTiny = 16.0;
  static const double iconSizeSmall = 20.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeExtraLarge = 40.0;
  static const double iconSizeHuge = 48.0;

  // Avatar Sizes
  static const double avatarSizeSmall = 32.0;
  static const double avatarSizeMedium = 40.0;
  static const double avatarSizeLarge = 56.0;
  static const double avatarSizeExtraLarge = 80.0;

  // Pet Image Sizes
  static const double petImageList = 60.0;
  static const double petImageCard = 80.0;
  static const double petImageDetail = 120.0;

  // Room Image Sizes
  static const double roomImageCardWidth = 120.0;
  static const double roomImageCardHeight = 90.0;

  // Minimum Touch Target (Apple HIG & Material Design)
  static const double minTouchTarget = 48.0; // spec §4: 48 x 48 dp

  // AppBar Height
  static const double appBarHeight = 56.0;

  // Bottom Navigation Height
  static const double bottomNavHeight = 80.0;

  // Tab Bar Height
  static const double tabBarHeight = 48.0;

  // Divider
  static const double dividerThickness = 1.0;
  static const double dividerIndent = 16.0;

  // Border Width
  static const double borderThin = 1.0;
  static const double borderMedium = 1.5;
  static const double borderThick = 2.0;

  // Shadow Elevation
  static const double elevationNone = 0.0;
  static const double elevationSmall = 1.0;
  static const double elevationMedium = 2.0;
  static const double elevationLarge = 4.0;
  static const double elevationExtraLarge = 8.0;
}
