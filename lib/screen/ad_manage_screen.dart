import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// 앱 진입 BottomSheet 광고를 관리하는 관리자 전용 화면
/// 컬렉션: bottom_sheet_ads
/// 필드:
///  - title: String
///  - imageUrl: String
///  - linkType: 'web' | 'deeplink'
///  - linkValue: String (web URL 또는 딥링크 문자열)
///  - isActive: bool
///  - startAt: Timestamp
///  - endAt: Timestamp
///  - priority: int
class AdManageScreen extends StatefulWidget {
  const AdManageScreen({super.key});

  @override
  State<AdManageScreen> createState() => _AdManageScreenState();
}

class _AdManageScreenState extends State<AdManageScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '광고 관리',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF7F7FA),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('bottom_sheet_ads')
            .orderBy('priority', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '광고를 불러오는 중 오류가 발생했습니다.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                '등록된 광고가 없습니다.\n오른쪽 아래 + 버튼을 눌러 추가해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final title = (data['title'] as String?) ?? '제목 없음';
              final imageUrl = (data['imageUrl'] as String?) ?? '';
              final linkType = (data['linkType'] as String?) ?? 'web';
              final linkValue = (data['linkValue'] as String?) ?? '';
              final isActive = (data['isActive'] as bool?) ?? true;
              final priority = (data['priority'] as int?) ?? 0;
              final Timestamp? startTs = data['startAt'] as Timestamp?;
              final Timestamp? endTs = data['endAt'] as Timestamp?;

              String periodText = '기간 제한 없음';
              if (startTs != null || endTs != null) {
                final start = startTs?.toDate();
                final end = endTs?.toDate();
                if (start != null && end != null) {
                  periodText =
                      '${_formatDate(start)} ~ ${_formatDate(end)}';
                } else if (start != null) {
                  periodText = '${_formatDate(start)} 이후';
                } else if (end != null) {
                  periodText = '${_formatDate(end)} 이전';
                }
              }

              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showEditAdDialog(doc.id, data),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 72,
                                  height: 72,
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Colors.grey,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Switch(
                                    value: isActive,
                                    activeColor: const Color(0xFF74512D),
                                    onChanged: (value) async {
                                      await doc.reference.update(
                                        <String, dynamic>{
                                          'isActive': value,
                                          'updatedAt':
                                              FieldValue.serverTimestamp(),
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '링크: $linkType / ${linkValue.isEmpty ? '미설정' : linkValue}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                periodText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '우선순위: $priority',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _confirmDeleteAd(doc),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: docs.length,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF74512D),
        foregroundColor: Colors.white,
        onPressed: () => _showEditAdDialog(null, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmDeleteAd(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '광고 삭제',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            '선택한 광고를 삭제하시겠습니까?',
            style: TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.black),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    try {
      final data = doc.data();
      final String? imageUrl = data['imageUrl'] as String?;
      await doc.reference.delete();

      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(imageUrl);
          await ref.delete();
        } catch (_) {
          // 이미지 삭제 실패는 무시
        }
      }
      Fluttertoast.showToast(msg: '광고가 삭제되었습니다.');
    } catch (e) {
      Fluttertoast.showToast(msg: '광고 삭제 중 오류가 발생했습니다.');
    }
  }

  Future<void> _showEditAdDialog(
    String? adId,
    Map<String, dynamic>? existingData,
  ) async {
    final TextEditingController titleController = TextEditingController(
      text: (existingData?['title'] as String?) ?? '',
    );
    final TextEditingController linkValueController = TextEditingController(
      text: (existingData?['linkValue'] as String?) ?? '',
    );
    final TextEditingController priorityController = TextEditingController(
      text: ((existingData?['priority'] as int?) ?? 0).toString(),
    );

    String linkType = (existingData?['linkType'] as String?) ?? 'web';
    bool isActive = (existingData?['isActive'] as bool?) ?? true;
    DateTime? startAt =
        (existingData?['startAt'] as Timestamp?)?.toDate();
    DateTime? endAt = (existingData?['endAt'] as Timestamp?)?.toDate();
    File? selectedImageFile;
    String? existingImageUrl = existingData?['imageUrl'] as String?;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> pickImage() async {
              final XFile? picked = await _imagePicker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 1024,
                maxHeight: 1024,
                imageQuality: 85,
              );
              if (picked == null) return;
              setStateDialog(() {
                selectedImageFile = File(picked.path);
              });
            }

            Future<void> pickDate({
              required bool isStart,
            }) async {
              final now = DateTime.now();
              final initialDate = isStart
                  ? (startAt ?? now)
                  : (endAt ?? now.add(const Duration(days: 7)));

              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 3),
              );
              if (picked == null) return;
              setStateDialog(() {
                if (isStart) {
                  startAt = picked;
                } else {
                  endAt = picked;
                }
              });
            }

            Future<void> onSave() async {
              if (isSaving) return;

              final String title = titleController.text.trim();
              final String linkValue = linkValueController.text.trim();
              final int priority =
                  int.tryParse(priorityController.text.trim()) ?? 0;

              if (title.isEmpty) {
                Fluttertoast.showToast(msg: '제목을 입력해주세요.');
                return;
              }
              if (existingImageUrl == null &&
                  selectedImageFile == null) {
                Fluttertoast.showToast(msg: '이미지를 선택해주세요.');
                return;
              }

              setStateDialog(() {
                isSaving = true;
              });

              try {
                final CollectionReference<Map<String, dynamic>> col =
                    FirebaseFirestore.instance
                        .collection('bottom_sheet_ads');

                final DocumentReference<Map<String, dynamic>> docRef =
                    adId == null ? col.doc() : col.doc(adId);

                String imageUrl = existingImageUrl ?? '';

                if (selectedImageFile != null) {
                  FirebaseStorage storage;
                  if (Platform.isIOS) {
                    storage = FirebaseStorage.instanceFor(
                      bucket: 'mileagethief.firebasestorage.app',
                    );
                  } else {
                    storage = FirebaseStorage.instance;
                  }

                  final String fileName =
                      '${docRef.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
                  final String storagePath =
                      'bottom_sheet_ads/$fileName';

                  final Reference ref =
                      storage.ref().child(storagePath);
                  final UploadTask uploadTask =
                      ref.putFile(selectedImageFile!);
                  final TaskSnapshot snapshot = await uploadTask;
                  if (snapshot.state == TaskState.success) {
                    imageUrl = await snapshot.ref.getDownloadURL();
                  }
                }

                final Map<String, dynamic> payload = <String, dynamic>{
                  'title': title,
                  'imageUrl': imageUrl,
                  'linkType': linkType,
                  'linkValue': linkValue,
                  'isActive': isActive,
                  'priority': priority,
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                if (startAt != null) {
                  payload['startAt'] = Timestamp.fromDate(startAt!);
                } else {
                  payload['startAt'] = null;
                }
                if (endAt != null) {
                  payload['endAt'] = Timestamp.fromDate(endAt!);
                } else {
                  payload['endAt'] = null;
                }

                if (adId == null) {
                  payload['createdAt'] = FieldValue.serverTimestamp();
                }

                await docRef.set(payload, SetOptions(merge: true));

                if (context.mounted) {
                  Navigator.of(context).pop();
                }

                Fluttertoast.showToast(
                  msg: adId == null ? '광고가 등록되었습니다.' : '광고가 수정되었습니다.',
                );
              } catch (e) {
                setStateDialog(() {
                  isSaving = false;
                });
                Fluttertoast.showToast(
                  msg: '저장 중 오류가 발생했습니다: $e',
                );
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                adId == null ? '광고 추가' : '광고 수정',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.black),
                      decoration: const InputDecoration(
                        labelText: '제목',
                        labelStyle: TextStyle(color: Colors.black54),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: linkType,
                            decoration: const InputDecoration(
                              labelText: '링크 타입',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'web',
                                child: Text('웹 링크'),
                              ),
                              DropdownMenuItem(
                                value: 'deeplink',
                                child: Text('딥링크(앱 내부 이동)'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setStateDialog(() {
                                linkType = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: linkValueController,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: linkType == 'web'
                            ? '웹 URL (https://...)'
                            : '딥링크 값 (예: branch:jungang)',
                        labelStyle: const TextStyle(color: Colors.black54),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickDate(isStart: true),
                            icon: const Icon(Icons.date_range),
                            label: Text(
                              startAt == null
                                  ? '시작일 선택'
                                  : '시작: ${_formatDate(startAt!)}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickDate(isStart: false),
                            icon: const Icon(Icons.date_range),
                            label: Text(
                              endAt == null
                                  ? '종료일 선택'
                                  : '종료: ${_formatDate(endAt!)}',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priorityController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.black),
                      decoration: const InputDecoration(
                        labelText: '우선순위 (작을수록 먼저 노출)',
                        labelStyle: TextStyle(color: Colors.black54),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Switch(
                          value: isActive,
                          activeColor: const Color(0xFF74512D),
                          onChanged: (value) {
                            setStateDialog(() {
                              isActive = value;
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '활성화',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '이미지',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: pickImage,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Builder(
                              builder: (context) {
                                if (selectedImageFile != null) {
                                  return Image.file(
                                    selectedImageFile!,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  );
                                }
                                if (existingImageUrl != null &&
                                    existingImageUrl!.isNotEmpty) {
                                  return Image.network(
                                    existingImageUrl!,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  );
                                }
                                return Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.add_a_photo_outlined,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'BottomSheet에 노출될 이미지를 선택하세요.\n가급적 16:9 비율을 권장합니다.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text(
                    '취소',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                TextButton(
                  onPressed: isSaving ? null : onSave,
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          '저장',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}


