import 'package:flutter/material.dart';

class RoleSelectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade900,
              Colors.blue.shade700,
              Colors.blue.shade500,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo or App Name
                Column(
                  children: [
                    Icon(Icons.home_repair_service, 
                        size: 80, 
                        color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'ระบบแจ้งซ่อม SMH ',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.black45,
                            offset: Offset(2.0, 2.0),),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'กรุณาเลือกบทบาทของคุณ',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 48),
                
                // Role Selection Buttons
                Column(
                  children: [
                    // User Button
                    _buildRoleButton(
                      context: context,
                      icon: Icons.person,
                      label: 'ผู้แจ้งซ่อม',
                      color: Colors.amber.shade700,
                      route: '/home',
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Technician Button
                    _buildRoleButton(
                      context: context,
                      icon: Icons.engineering,
                      label: 'ช่างซ่อม',
                      color: Colors.teal.shade700,
                      route: '/technician_home',
                    ),
                  ],
                ),
                
                SizedBox(height: 40),
                
                // Footer Text
                Text(
                  'เวอร์ชัน 1.0.0',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required String route,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 5,
          shadowColor: Colors.black.withOpacity(0.3),
        ),
        onPressed: () {
          Navigator.pushReplacementNamed(context, route);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: Colors.white),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}