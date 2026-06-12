import 'package:flutter/material.dart';
import '../screens/common/notifications_dropdown_menu.dart'; // O la ruta donde lo guardaste
import '../core/app_theme.dart';
class WebNavItem {
  const WebNavItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

/// Shell escritorio: barra lateral + cabecera + contenido.
class WebAppShell extends StatelessWidget {
  const WebAppShell({
    super.key,
    required this.brandTitle,
    required this.navItems,
    required this.currentIndex,
    required this.onNavTap,
    required this.body,
    this.brandSubtitle,
    this.primaryAction,
    this.onNotifications,
    this.onSettings,
    this.onLogout,
    this.userLabel,
    this.userSubtitle,
  });

  final String brandTitle;
  final String? brandSubtitle;
  final List<WebNavItem> navItems;
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final Widget body;
  final Widget? primaryAction;
  final VoidCallback? onNotifications;
  final VoidCallback? onSettings;
  final VoidCallback? onLogout;
  final String? userLabel;
  final String? userSubtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WebSidebar(
            brandTitle: brandTitle,
            brandSubtitle: brandSubtitle,
            navItems: navItems,
            currentIndex: currentIndex,
            onNavTap: onNavTap,
            primaryAction: primaryAction,
            onSettings: onSettings,
            onLogout: onLogout,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WebShellHeader(
                  onNotifications: onNotifications,
                  onLogout: onLogout,
                  userLabel: userLabel,
                  userSubtitle: userSubtitle,
                  hideLogout: onLogout != null && onSettings != null,
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WebSidebar extends StatelessWidget {
  const _WebSidebar({
    required this.brandTitle,
    required this.brandSubtitle,
    required this.navItems,
    required this.currentIndex,
    required this.onNavTap,
    required this.primaryAction,
    required this.onSettings,
    required this.onLogout,
  });

  final String brandTitle;
  final String? brandSubtitle;
  final List<WebNavItem> navItems;
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final Widget? primaryAction;
  final VoidCallback? onSettings;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: KeepiColors.cardBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.medical_services_rounded,
                      color: KeepiColors.orange,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        brandTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: KeepiColors.slate,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (brandSubtitle != null && brandSubtitle!.isNotEmpty)
                        Text(
                          brandSubtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: KeepiColors.slateLight,
                            letterSpacing: 0.8,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: KeepiColors.cardBorder),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (var i = 0; i < navItems.length; i++)
                  _SidebarNavTile(
                    item: navItems[i],
                    selected: currentIndex == i,
                    onTap: () => onNavTap(i),
                  ),
              ],
            ),
          ),
          if (primaryAction != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: primaryAction!,
            ),
          const Divider(height: 1, color: KeepiColors.cardBorder),
          if (onSettings != null)
            _SidebarFooterLink(
              icon: Icons.settings_outlined,
              label: 'Configuración',
              onTap: onSettings!,
            ),
          if (onLogout != null)
            _SidebarFooterLink(
              icon: Icons.logout_rounded,
              label: 'Cerrar sesión',
              onTap: onLogout!,
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _SidebarNavTile extends StatelessWidget {
  const _SidebarNavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final WebNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? KeepiColors.orangeSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: selected ? KeepiColors.orange : KeepiColors.slateLight,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? KeepiColors.slate : KeepiColors.slateLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooterLink extends StatelessWidget {
  const _SidebarFooterLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: KeepiColors.slateLight),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: KeepiColors.slateLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WebShellHeader extends StatelessWidget {
  const _WebShellHeader({
    required this.onNotifications,
    required this.onLogout,
    required this.userLabel,
    required this.userSubtitle,
    required this.hideLogout,
  });

  final VoidCallback? onNotifications;
  final VoidCallback? onLogout;
  final String? userLabel;
  final String? userSubtitle;
  final bool hideLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: KeepiColors.cardBorder)),
      ),
      child: Row(
        children: [
          const Spacer(),
          NotificationBellMenu(onViewAll: onNotifications),
          if (userLabel != null) ...[
            const SizedBox(width: 14),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  userLabel!,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: KeepiColors.slate,
                  ),
                ),
                if (userSubtitle != null && userSubtitle!.isNotEmpty)
                  Text(
                    userSubtitle!,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: KeepiColors.skyBlue,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 18,
              backgroundColor: KeepiColors.skyBlueSoft,
              child: Text(
                userLabel!.trim().isEmpty
                    ? '?'
                    : userLabel!.trim()[0].toUpperCase(),
                style: const TextStyle(
                  color: KeepiColors.skyBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          if (!hideLogout && onLogout != null) ...[
            const SizedBox(width: 8),
            _HeaderIconButton(icon: Icons.logout_rounded, onTap: onLogout!),
          ],
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: KeepiColors.cardBorder),
        ),
        child: Icon(icon, size: 19, color: KeepiColors.slate),
      ),
    );
  }
}

/// Barra superior simple para rol USER (sin sidebar).
class WebUserShell extends StatelessWidget {
  const WebUserShell({
    super.key,
    required this.body,
    required this.onNotifications,
    required this.onSettings,
    required this.onLogout,
    required this.userName,
  });

  final Widget body;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;
  final VoidCallback onLogout;
  final String userName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      body: Column(
        children: [
          _WebShellHeader(
            onNotifications: onNotifications,
            onLogout: onLogout,
            userLabel: userName,
            userSubtitle: 'DOCUMENTOS',
            hideLogout: true,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 200,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      right: BorderSide(color: KeepiColors.cardBorder),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                          children: [
                            _SidebarNavTile(
                              item: const WebNavItem(
                                icon: Icons.folder_rounded,
                                label: 'Mis documentos',
                              ),
                              selected: true,
                              onTap: () {},
                            ),
                          ],
                        ),
                      ),
                      _SidebarFooterLink(
                        icon: Icons.settings_outlined,
                        label: 'Configuración',
                        onTap: onSettings,
                      ),
                      _SidebarFooterLink(
                        icon: Icons.logout_rounded,
                        label: 'Cerrar sesión',
                        onTap: onLogout,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
