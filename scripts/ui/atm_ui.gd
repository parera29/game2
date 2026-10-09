extends UIWindow
## Cajero automático: ingresar y retirar dinero (el banco protege de multas y atracos).

var _info: Label
var _spin: SpinBox


func build() -> void:
	var body := make_window(Vector2(480, 0), "Cajero · Banco Redmont")
	_info = UITheme.label("", 18)
	body.add_child(_info)
	body.add_child(UITheme.label("El dinero del banco no se pierde si te detienen o te atracan.\nLímite de ingreso diario: %s" % UITheme.money(GameState.DAILY_DEPOSIT_LIMIT), 13, UITheme.TEXT_DIM))
	_spin = SpinBox.new()
	_spin.min_value = 1
	_spin.max_value = 1000000
	_spin.value = 100
	_spin.prefix = "$"
	body.add_child(_spin)
	var h := HBoxContainer.new()
	body.add_child(h)
	h.add_child(UITheme.button("Ingresar", func() -> void: _op(true), 120))
	h.add_child(UITheme.button("Retirar", func() -> void: _op(false), 120))
	var all_in := func() -> void:
		_spin.value = maxi(1, mini(GameState.cash, GameState.DAILY_DEPOSIT_LIMIT - GameState.deposited_today))
		_op(true)
	h.add_child(UITheme.button("Ingresar todo", all_in, 150))
	_refresh()


func _op(deposit: bool) -> void:
	var amount := int(_spin.value)
	var ok := GameState.deposit(amount) if deposit else GameState.withdraw(amount)
	if ok:
		Audio.play("cash", -6.0)
	else:
		Audio.play("error", -6.0)
	_refresh()


func _refresh() -> void:
	_info.text = "Efectivo: %s     Banco: %s\nIngresado hoy: %s" % [UITheme.money(GameState.cash), UITheme.money(GameState.bank), UITheme.money(GameState.deposited_today)]
