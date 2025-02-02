package handmade

import "base:runtime"
import "core:fmt"
import win "core:sys/windows"

Win32_Offscreen_Buffer :: struct {
	info:            win.BITMAPINFO,
	memory:          rawptr,
	width:           i32,
	height:          i32,
	pitch:           i32,
	bytes_per_pixel: i32,
}

Win32_Window_Dimension :: struct {
	width:  i32,
	height: i32,
}

global_running: bool
global_backbuffer: Win32_Offscreen_Buffer

main :: proc() {
	instance := win.HINSTANCE(win.GetModuleHandleW(nil))

	win32_resize_dib_section(&global_backbuffer, 1280, 720)

	window_class: win.WNDCLASSW = {
		style         = win.CS_HREDRAW | win.CS_VREDRAW,
		lpfnWndProc   = win32_main_window_callback,
		hInstance     = instance,
		lpszClassName = win.L("HandmadeHeroWindowClass"),
	}

	if win.RegisterClassW(&window_class) == 0 {
		fmt.eprintln("Failed to register window class")
		return
	}

	window := win.CreateWindowExW(
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

	if window == nil {
		fmt.eprintln("Failed to create window")
		return
	}

	x_offset: i32
	y_offset: i32

	global_running = true

	for global_running {
		message: win.MSG

		for win.PeekMessageW(&message, nil, 0, 0, win.PM_REMOVE) {

			if message.message == win.WM_QUIT {
				global_running = false
			}

			win.TranslateMessage(&message)
			win.DispatchMessageW(&message)
		}

		render_weird_gradient(global_backbuffer, x_offset, y_offset)

		device_context := win.GetDC(window)
		dimension := win32_get_window_dimension(window)

		win32_display_buffer_in_window(
			device_context,
			dimension.width,
			dimension.height,
			global_backbuffer,
		)
		win.ReleaseDC(window, device_context)

		x_offset += 1
		y_offset += 2
	}
}

win32_main_window_callback :: proc "stdcall" (
	window: win.HWND,
	message: win.UINT,
	wparam: win.WPARAM,
	lparam: win.LPARAM,
) -> win.LRESULT {
	context = runtime.default_context()

	result: win.LRESULT

	switch message {
	case win.WM_CLOSE:
		global_running = false

	case win.WM_ACTIVATEAPP:
		fmt.println("WM_ACTIVATEAPP")

	case win.WM_DESTROY:
		global_running = false

	case win.WM_PAINT:
		paint: win.PAINTSTRUCT
		device_context := win.BeginPaint(window, &paint)

		x := paint.rcPaint.left
		y := paint.rcPaint.right
		width := paint.rcPaint.right - paint.rcPaint.left
		height := paint.rcPaint.bottom - paint.rcPaint.top

		dimension := win32_get_window_dimension(window)

		win32_display_buffer_in_window(
			device_context,
			dimension.width,
			dimension.height,
			global_backbuffer,
		)

		win.EndPaint(window, &paint)

	case:
		result = win.DefWindowProcW(window, message, wparam, lparam)
	}

	return result
}

win32_get_window_dimension :: proc(window: win.HWND) -> Win32_Window_Dimension {
	result: Win32_Window_Dimension

	client_rect: win.RECT
	win.GetClientRect(window, &client_rect)
	result.width = client_rect.right - client_rect.left
	result.height = client_rect.bottom - client_rect.top

	return result
}

win32_resize_dib_section :: proc(buffer: ^Win32_Offscreen_Buffer, width, height: i32) {
	if buffer.memory != nil {
		win.VirtualFree(buffer.memory, 0, win.MEM_RELEASE)
	}

	buffer.width = width
	buffer.height = height
	buffer.bytes_per_pixel = 4

	buffer.info = {
		bmiHeader = {
			biSize = size_of(win.BITMAPINFOHEADER),
			biWidth = buffer.width,
			biHeight = -buffer.height,
			biPlanes = 1,
			biBitCount = 32,
			biCompression = win.BI_RGB,
		},
	}

	bitmap_memory_size := uint(buffer.width * buffer.height * buffer.bytes_per_pixel)
	buffer.memory = win.VirtualAlloc(nil, bitmap_memory_size, win.MEM_COMMIT, win.PAGE_READWRITE)

	buffer.pitch = width * buffer.bytes_per_pixel
}

render_weird_gradient :: proc(buffer: Win32_Offscreen_Buffer, blue_offset, green_offset: i32) {
	pixel := ([^]u32)(buffer.memory)

	for y in 0 ..< buffer.height {
		for x in 0 ..< buffer.width {
			blue := u8(x + blue_offset)
			green := u8(y + green_offset)

			pixel[y * buffer.width + x] = (u32(green) << 8) | u32(blue)
		}
	}
}

win32_display_buffer_in_window :: proc(
	device_context: win.HDC,
	window_width, window_height: i32,
	buffer: Win32_Offscreen_Buffer,
) {
	info := buffer.info

	win.StretchDIBits(
		device_context,
		0,
		0,
		window_width,
		window_height,
		0,
		0,
		buffer.width,
		buffer.height,
		buffer.memory,
		&info,
		win.DIB_RGB_COLORS,
		win.SRCCOPY,
	)
}
