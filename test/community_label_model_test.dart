import 'package:flutter_test/flutter_test.dart';
import 'package:mileage_thief/models/community_label_model.dart';
import 'package:mileage_thief/services/community_label_service.dart';

void main() {
  test('dedupe keeps first label for duplicate keys', () {
    final labels = CommunityLabel.dedupe([
      CommunityLabel.branch(branchId: 'jungang', name: '중앙상품권'),
      CommunityLabel.branch(branchId: 'jungang', name: '다른 이름'),
      CommunityLabel.giftcard(giftcardId: 'shinsegae', name: '신세계상품권'),
    ]);

    expect(labels, hasLength(2));
    expect(labels.first.displayName, '중앙상품권');
  });

  test('payload builds labelKeys and entityRefs from labels', () {
    final payload = CommunityLabelPayload.fromLabels([
      CommunityLabel.branch(branchId: 'jungang', name: '중앙상품권'),
      CommunityLabel.giftcard(giftcardId: 'shinsegae', name: '신세계상품권'),
      CommunityLabel.card(cardId: 'hyundai_m', name: '현대카드 M'),
      CommunityLabel.giftcardCalculator(),
    ]);

    expect(payload.labelKeys, [
      'branch:jungang',
      'giftcard:shinsegae',
      'card:hyundai_m',
      'calculator:giftcard',
    ]);
    expect(payload.entityRefs['branchIds'], ['jungang']);
    expect(payload.entityRefs['branchId'], 'jungang');
    expect(payload.entityRefs['giftcardIds'], ['shinsegae']);
    expect(payload.entityRefs['giftcardId'], 'shinsegae');
    expect(payload.entityRefs['cardIds'], ['hyundai_m']);
    expect(payload.entityRefs['cardId'], 'hyundai_m');
    expect(payload.entityRefs['calculatorKinds'], ['giftcard']);
  });

  test('listFromEntityRefs restores legacy refs as labels', () {
    final labels = CommunityLabel.listFromEntityRefs({
      'branchId': 'jungang',
      'giftcardIds': ['lotte', 'shinsegae'],
      'cardId': 'hyundai_m',
      'calculatorKinds': ['giftcard'],
    });

    expect(labels.map((label) => label.key), [
      'branch:jungang',
      'giftcard:lotte',
      'giftcard:shinsegae',
      'card:hyundai_m',
      'calculator:giftcard',
    ]);
  });

  test('filterCandidates matches names, ids, and subtitles', () {
    final filtered = CommunityLabelService.filterCandidates([
      CommunityLabel.branch(branchId: 'myeongdong_a', name: '명동 상품권'),
      CommunityLabel.giftcard(giftcardId: 'shinsegae', name: '신세계상품권'),
      CommunityLabel.card(
        cardId: 'hyundai_m',
        name: '현대카드 M',
        issuerName: '현대카드',
      ),
      CommunityLabel.giftcardCalculator(),
    ], '현대');

    expect(filtered.map((label) => label.key), [
      'card:hyundai_m',
    ]);
  });

  test('branchItemFromData builds branch label with address description', () {
    final item = CommunityLabelService.branchItemFromData(
      branchId: 'gogo',
      data: {
        'name': '고고상품권',
        'address': '서울 중구 명동길 1',
      },
    );

    expect(item.label.key, 'branch:gogo');
    expect(item.label.displayName, '고고상품권');
    expect(item.description, '서울 중구 명동길 1');
  });

  test('giftcardItemFromData keeps sortOrder for browse sorting', () {
    final item = CommunityLabelService.giftcardItemFromData(
      giftcardId: 'shinsegae',
      data: {
        'name': '신세계상품권',
        'sortOrder': 3,
      },
    );

    expect(item.label.key, 'giftcard:shinsegae');
    expect(item.label.displayName, '신세계상품권');
    expect(item.sortOrder, 3);
  });

  test('groupCardItems groups by issuerId, issuerName, and other issuer', () {
    CommunityLabelBrowseItem cardItem({
      required String id,
      required String name,
      required String issuerId,
      required String issuerName,
    }) {
      return CommunityLabelBrowseItem(
        label: CommunityLabel.card(
          cardId: id,
          name: name,
          issuerName: issuerName,
        ),
        groupId: issuerId,
        groupName: issuerName,
      );
    }

    final groups = CommunityLabelService.groupCardItems(
      issuers: const [
        CommunityLabelGroupInfo(id: 'hyundai', title: '현대카드'),
        CommunityLabelGroupInfo(id: 'shinhan', title: '신한카드'),
      ],
      cardItems: [
        cardItem(
          id: 'hyundai_m',
          name: '현대카드 M',
          issuerId: 'hyundai',
          issuerName: '다른 이름',
        ),
        cardItem(
          id: 'shinhan_air',
          name: '신한 Air',
          issuerId: '',
          issuerName: '신한카드',
        ),
        cardItem(
          id: 'unknown_card',
          name: '새 카드',
          issuerId: '',
          issuerName: '새 카드사',
        ),
      ],
    );

    expect(groups.map((group) => group.title), [
      '신한카드',
      '현대카드',
      '기타 카드사',
    ]);
    expect(groups[0].items.map((item) => item.label.key), ['card:shinhan_air']);
    expect(groups[1].items.map((item) => item.label.key), ['card:hyundai_m']);
    expect(
        groups[2].items.map((item) => item.label.key), ['card:unknown_card']);
  });

  test('flattenBrowseData contains browse labels without calculator candidate',
      () {
    final data = CommunityLabelBrowseData(
      branchItems: [
        CommunityLabelBrowseItem(
          label: CommunityLabel.branch(branchId: 'gogo', name: '고고상품권'),
        ),
      ],
      giftcardItems: [
        CommunityLabelBrowseItem(
          label: CommunityLabel.giftcard(
            giftcardId: 'lotte',
            name: '롯데상품권',
          ),
        ),
      ],
      cardGroups: [
        CommunityLabelGroup(
          id: 'issuer:hyundai',
          title: '현대카드',
          items: [
            CommunityLabelBrowseItem(
              label: CommunityLabel.card(
                cardId: 'hyundai_m',
                name: '현대카드 M',
                issuerName: '현대카드',
              ),
            ),
          ],
        ),
      ],
    );

    final keys = CommunityLabelService.flattenBrowseData(data)
        .map((item) => item.label.key)
        .toList();

    expect(keys, ['branch:gogo', 'giftcard:lotte', 'card:hyundai_m']);
    expect(keys, isNot(contains('calculator:giftcard')));
  });
}
