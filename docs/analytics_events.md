# Firebase Analytics Event Dictionary

This app uses `AnalyticsService` as the single entry point for Firebase
Analytics. Send only product-flow metadata. Do not send email, display names,
profile images, URLs, free-form text, notification bodies, memos, or exact
transaction amounts.

## Common Rules

- Logged-in users are connected with Firebase Auth UID through `setUserId`.
- Every event includes `is_logged_in` and `platform`.
- Monetary values must be sent as `*_bucket` values. Use
  `AnalyticsService.amountBucket`.
- Quantities must be sent as `qty_bucket` or `quantity_bucket`. Use
  `AnalyticsService.quantityBucket`.
- Firebase reserves `notification_open`, so the app logs
  `notification_opened`.

## Common Events

| Event | Required parameters | Notes |
| --- | --- | --- |
| `app_open` |  | App entered after Firebase initialization. |
| `screen_view` | `firebase_screen` | Sent by `logScreenView` and route observer. |
| `home_tab_selected` | `tab`, `source` | Home bottom nav and guide shortcuts. |
| `giftcard_subtab_selected` | `tab`, `source` | Product giftcard tabs. |
| `sub_tab_selected` | `tab_group`, `tab`, `source` | Secondary tabs outside giftcard. |
| `cta_tapped` | `screen`, `cta`, `source` | Generic CTA fallback. |
| `external_link_open` | `screen`, `entity_type`, `entity_id` | Never send raw URLs. |
| `share_started` | `screen`, `entity_type`, `entity_id` | Share sheet opened. |
| `deep_link_open` | `source`, `entity_type`, `entity_id` | Branch/internal deep links. |
| `notification_opened` | `notification_type`, `entity_type`, `entity_id` | FCM/local notification taps. |

## Guide And Radar

| Event | Parameters |
| --- | --- |
| `guide_quick_action_clicked` | `action`, `target_screen` |
| `guide_section_post_open` | `section`, `post_id`, `board_id` |
| `guide_ad_clicked` | `ad_id`, `link_type` |
| `radar_item_open` | `item_type`, `entity_id`, `source` |
| `radar_subscribe_start` | `item_type`, `entity_id` |
| `radar_subscribe_success` | `item_type`, `entity_id` |
| `radar_subscribe_failed` | `item_type`, `error_code` |
| `radar_tab_selected` | `tab` |
| `radar_push_toggled` | `entity_id`, `entity_type`, `state` |
| `radar_subscription_extended` | `entity_id`, `entity_type` |
| `radar_subscription_deleted` | `entity_id`, `entity_type` |
| `radar_match_open` | `entity_id`, `entity_type` |

## Community

| Event | Parameters |
| --- | --- |
| `community_board_selected` | `board_id`, `source` |
| `community_post_open` | `post_id`, `board_id`, `source` |
| `community_view_mode_changed` | `mode` |
| `community_search_open` | `source` |
| `community_create_start` | `board_id`, `source` |
| `post_view` | `post_id`, `board_id` |
| `post_like_toggled` | `post_id`, `board_id`, `state` |
| `post_bookmark_toggled` | `post_id`, `board_id`, `state` |
| `post_shared` | `post_id`, `board_id` |
| `comment_created` | `post_id`, `board_id`, `is_reply`, `has_image` |
| `comment_liked` | `post_id`, `comment_id`, `state` |
| `reply_started` | `post_id`, `comment_id` |
| `report_submitted` | `entity_type`, `reason` |
| `post_label_clicked` | `label_key`, `label_type`, `target_id`, `post_id` |
| `post_create_started` | `board_id`, `source` |
| `post_create_submitted` | `board_id`, `has_image`, `label_count` |
| `post_create_success` | `board_id`, `has_image`, `label_count` |
| `post_create_failed` | `board_id`, `error_code` |

## Giftcard

| Event | Parameters |
| --- | --- |
| `giftcard_dashboard_period_changed` | `period_type`, `year`, `month` |
| `giftcard_kpi_open` | `kpi_type` |
| `giftcard_section_info_open` | `section` |
| `giftcard_monthly_trend_expanded` | `period_type` |
| `giftcard_daily_filter_applied` | `giftcard_count_bucket` |
| `giftcard_ledger_item_open` | `entry_type`, `giftcard_id` |
| `gift_buy_started` | `mode` |
| `gift_buy_template_applied` | `source` |
| `gift_buy_saved` | `mode`, `giftcard_id`, `qty_bucket`, `buy_total_bucket` |
| `gift_buy_failed` | `mode`, `error_code` |
| `gift_sell_started` | `mode` |
| `gift_sell_saved` | `mode`, `branch_id`, `qty_bucket`, `sell_total_bucket` |
| `gift_sell_failed` | `mode`, `error_code` |
| `giftcard_branch_open` | `branch_id`, `source` |
| `giftcard_rate_open` | `giftcard_id`, `source` |
| `giftcard_rate_filter_applied` | `branch_count_bucket`, `giftcard_count_bucket` |
| `giftcard_settlement_calculated` | `line_count_bucket` |
| `giftcard_settlement_saved` | `line_count_bucket`, `branch_id` |
| `branch_created` | `source` |
| `branch_updated` | `source` |

## Cards, Deals, Login, Ads

| Event | Parameters |
| --- | --- |
| `card_hub_filter_changed` | `filter`, `result_count_bucket` |
| `card_recommendation_open` | `card_id`, `source` |
| `card_apply_clicked` | `entity_id`, `source` |
| `card_search_performed` | `query_length` |
| `card_catalog_filter_changed` | `filter`, `value` |
| `card_detail_open` | `card_id`, `source` |
| `card_liked` | `card_id`, `state` |
| `card_shared` | `card_id` |
| `issuer_link_open` | `card_id` |
| `card_feed_post_open` | `post_id`, `card_id` |
| `my_card_dashboard_open` | `source` |
| `manual_transaction_saved` | `card_id`, `amount_krw_bucket` |
| `transaction_override_saved` | `card_id`, `entity_id`, `amount_krw_bucket` |
| `deals_category_open` | `category` |
| `flight_deal_filter_applied` | `filter_type`, `result_count_bucket` |
| `flight_deal_sort_changed` | `sort` |
| `flight_deal_open` | `deal_id`, `agency_code`, `airline_code` |
| `price_change_sort_unlocked` | `result` |
| `deal_alert_step_changed` | `step` |
| `deal_alert_created` | `route`, `price_bucket`, `period_days` |
| `deal_alert_failed` | `error_code` |
| `login_attempt` | `provider` |
| `login_success` | `provider`, `sync_peanuts` |
| `login_failed` | `provider`, `error_code` |
| `logout` | `result` |
| `account_delete_requested` | `source` |
| `account_deleted` | `result` |
| `profile_image_updated` | `result` |
| `display_name_updated` | `result` |
| `level_detail_open` | `source` |
| `sky_effect_open` | `source` |
| `ad_loaded` | `screen`, `ad_format` |
| `ad_failed` | `screen`, `ad_format`, `error_code` |
| `ad_impression` | `screen`, `ad_format` |
| `ad_reward_granted` | `screen`, `ad_format`, `reward_qty_bucket` |
| `ad_removal_activated` | `screen`, `source` |
