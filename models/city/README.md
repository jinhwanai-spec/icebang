# 버려진 밤 도시 건물 키트

단위 m, Y-up, 모듈 정면 = +Z. Godot 4 에서 .glb 그대로 가져오면 됩니다.

## 모듈 규격
| 종류 | 크기 | 원점 |
|---|---|---|
| `wall_*` 위층 외벽 | 폭 3m × 높이 3m | 벽 뒷면 아래 가운데 (뒷면 z=0, 앞으로 0.22m) |
| `ground_*` 1층 | 폭 3m × 높이 3.6m | 같음 (level_builder 의 창문 시작 높이 3.6m 와 맞춤) |
| `roof_parapet` 옥상 난간 | 폭 3m | 같음, 지붕 높이에 둠 |
| `corner_pillar` | 0.6m 각, 높이 3m | 모서리 중심 |
| `roof_*`, `prop_*` | 제각각 | 바닥 가운데 |

`fire_escape` 는 층마다 위로 쌓으면 사다리가 이어집니다.

## 재질
- `Wall` 은 건물마다 색을 바꿀 수 있도록 따로 분리 (level_builder 의 `_building_mats` 로 덮어쓰기 가능)
- `Glass*`, `Neon*`, `Lamp` 은 발광 재질 → WorldEnvironment 의 Glow 를 켜야 빛남

## 완성 건물 (`building_*`)
모듈로 조립한 견본. 각 파일에 `Collision-colonly` 상자가 들어 있어 가져오면 충돌체가 자동으로 생깁니다.
- building_shops_3f: 9×9m, 3층, 벽돌
- building_apart_4f: 12×9m, 4층, 발코니
- building_tall_5f: 6×9m, 5층, 비상계단 + 물탱크

다시 만들려면 `tools/asset_gen/kit.py` 실행 (numpy 만 필요).
