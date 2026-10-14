# 자연 키트 (풀이 자란 버려진 도시)

단위 m, Y-up, 원점 = 바닥 가운데. 건물 키트와 같은 각진 로우폴리 스타일.

| 종류 | 파일 | 메모 |
|---|---|---|
| 나무 | tree_round_a/b, tree_round_autumn, tree_pine, tree_dead, tree_birch, tree_sapling | 높이 약 5~6m (사피링 2m). 사피링 외에는 줄기 충돌체(`Collision-colonly`) 포함 |
| 덤불 | bush_round, bush_flower, bush_small, hedge_3m | 덤불은 충돌 없음(통과 가능 = 숨기 좋음), 울타리(hedge)만 충돌 있음 |
| 풀/꽃 | grass_clump, grass_reeds, weeds_crack, flower_patch | weeds_crack 은 보도 틈 잡초 줄 (길이 2m) |
| 바닥 | log_fallen, stump, mushrooms_glow, mushrooms_red, leaf_pile | 통나무·그루터기는 충돌 있음. mushrooms_glow 는 발광(밤 맵 포인트) |
| 건물용 | ivy_wall_3x3, vines_hanging_3m | 담쟁이는 건물 외벽 모듈(3×3m)과 같은 원점에 겹쳐 두면 벽 앞면에 붙음. 늘어진 덩굴은 roof_parapet 윗면 앞쪽(+0.85m, z 0.28)에 둠 |

다시 만들려면 `tools/asset_gen/nature.py` 실행 (numpy 만 필요).
