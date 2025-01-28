package handmade_hero

import "base:runtime"
import "core:fmt"
import win "core:sys/windows"

main :: proc() {
	instance := win.HINSTANCE(win.GetModuleHandleW(nil))

	window_class: win.WNDCLASSW
	window_class.lpfnWndProc = main_window_callback
	window_class.hInstance = instance
	window_class.lpszClassName = win.L("HandmadeHeroWindowClass")

	if win.RegisterClassW(&window_class) == 0 {
		fmt.eprintln("Failed to register window class")
		return
	}

	window_handle := win.CreateWindowExW(
		0,
		window_class.lpszClassName,
		win.L("Handmade Hero"),
		win.WS_OVERLAPPEDWINDOW | win.WS_VISIBLE,
		win.CW_USEDEFAULT,
		win.CW_USEDEFAULT,
		win.CW_USEDEFAULT,
		win.CW_USEDEFAULT,
		nil,
		nil,
		instance,
		nil,
	)

	if window_handle == nil {
		fmt.eprintln("Failed to create window")
		return
	}

	for {
		message: win.MSG
		message_result := win.GetMessageW(&message, nil, 0, 0)
		if message_result > 0 {
			win.TranslateMessage(&message)
			win.DispatchMessageW(&message)
		} else {
			break
		}
	}
}

main_window_callback :: proc "stdcall" (
	window: win.HWND,
	message: win.UINT,
	wparam: win.WPARAM,
	lparam: win.LPARAM,
) -> win.LRESULT {
	context = runtime.default_context()
	result: win.LRESULT

	switch message {
	case win.WM_SIZE:
		fmt.println("WM_SIZE")

	case win.WM_CLOSE:
		fmt.println("WM_CLOSE")

	case win.WM_ACTIVATEAPP:
		fmt.println("WM_ACTIVATEAPP")

	case win.WM_DESTROY:
		fmt.println("WM_DESTROY")

	case win.WM_PAINT:
		paint: win.PAINTSTRUCT
		device_context := win.BeginPaint(window, &paint)
		x := paint.rcPaint.left
		y := paint.rcPaint.right
		width := paint.rcPaint.right - paint.rcPaint.left
		height := paint.rcPaint.bottom - paint.rcPaint.top
		@(static) operation := win.WHITENESS
		win.PatBlt(device_context, x, y, width, height, operation)
		if operation == win.WHITENESS {
			operation = win.BLACKNESS
		} else {
			operation = win.WHITENESS
		}
		win.EndPaint(window, &paint)

	case:
		result = win.DefWindowProcW(window, message, wparam, lparam)
	}

	return result
}
