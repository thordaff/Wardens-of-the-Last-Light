class_name MeshMerger
extends Node3D
## Menggabungkan MeshInstance3D primitif di bawah node ini menjadi satu mesh per
## (material, group) saat _ready, supaya satu bangunan = beberapa draw call saja.
## Anak yang ada di group (mis. "lit_windows") digabung terpisah dan mesh hasilnya
## masuk group yang sama. Subtree MeshMerger lain dilewati (mereka menggabung sendiri).


func _ready() -> void:
	merge()


func merge() -> void:
	var buckets := {}
	for mi in _collect(self):
		var groups := mi.get_groups()
		var key := (
			"%d|%s"
			% [mi.material_override.get_instance_id() if mi.material_override else 0, groups]
		)
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(mi)
	for key in buckets:
		var parts: Array = buckets[key]
		var first: MeshInstance3D = parts[0]
		var st := SurfaceTool.new()
		for mi: MeshInstance3D in parts:
			st.append_from(mi.mesh, 0, _relative_transform(mi))
		var merged := MeshInstance3D.new()
		merged.name = "Merged"
		merged.mesh = st.commit()
		merged.material_override = first.material_override
		merged.visible = first.visible
		for group in first.get_groups():
			merged.add_to_group(group, true)
		add_child(merged)
		for mi: MeshInstance3D in parts:
			mi.get_parent().remove_child(mi)
			mi.free()


func _collect(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshMerger:
			continue
		if child is MeshInstance3D and child.get_child_count() == 0 and child.mesh != null:
			out.append(child)
		else:
			out.append_array(_collect(child))
	return out


func _relative_transform(node: Node3D) -> Transform3D:
	var t := node.transform
	var p := node.get_parent()
	while p != self:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t
