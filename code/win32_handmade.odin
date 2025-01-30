package handmade

import "base:runtime"
import "core:fmt"
import win "core:sys/windows"

running: bool
bitmap_info: win.BITMAPINFO
bitmap_memory: rawptr
bitmap_width: i32
bitmap_height: i32

main :: proc() {
	instance := win.HINSTANCE(win.GetModuleHandleW(nil))

	window_class := win.WNDCLASSW {
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

	running = true

	for running {
		message: win.MSG

		for win.PeekMessageW(&message, nil, 0, 0, win.PM_REMOVE) {

			if message.message == win.WM_QUIT {
				running = false
			}

			win.TranslateMessage(&message)
			win.DispatchMessageW(&message)

		}

		render_weird_gradient(x_offset, y_offset)

		device_context := win.GetDC(window)
		client_rect: win.RECT
		win.GetClientRect(window, &client_rect)
		window_width := client_rect.right - client_rect.left
		window_height := client_rect.bottom - client_rect.top
		win32_update_window(device_context, client_rect, 0, 0, window_width, window_height)
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
	case win.WM_SIZE:
		client_rect: win.RECT
		win.GetClientRect(window, &client_rect)
		width := client_rect.right - client_rect.left
		height := client_rect.bottom - client_rect.top
		win32_resize_dib_section(width, height)

	case win.WM_CLOSE:
		running = false

	case win.WM_ACTIVATEAPP:
		fmt.println("WM_ACTIVATEAPP")

	case win.WM_DESTROY:
		running = false

	case win.WM_PAINT:
		paint: win.PAINTSTRUCT
		device_context := win.BeginPaint(window, &paint)

		x := paint.rcPaint.left
		y := paint.rcPaint.right
		width := paint.rcPaint.right - paint.rcPaint.left
		height := paint.rcPaint.bottom - paint.rcPaint.top

		client_rect: win.RECT
		win.GetClientRect(window, &client_rect)

		win32_update_window(device_context, client_rect, x, y, width, height)

		win.EndPaint(window, &paint)

	case:
		result = win.DefWindowProcW(window, message, wparam, lparam)
	}

	return result
}

win32_resize_dib_section :: proc(width, height: i32) {
	if bitmap_memory != nil {
		win.VirtualFree(bitmap_memory, 0, win.MEM_RELEASE)
	}

	bitmap_width = width
	bitmap_height = height

	bitmap_info = {
		bmiHeader = {
			biSize = size_of(win.BITMAPINFOHEADER),	
			biWidth = bitmap_width,
			biHeight = bitmap_height,
			biPlanes = 1,
			biBitCount = 32,
			biCompression = win.BI_RGB,
		},
	}

	bytes_per_pixel: i32 = 4
	bitmap_memory_size := uint(bitmap_width * bitmap_height * bytes_per_pixel)

	pitch := width * bytes_per_pixel
	bitmap_memory = win.VirtualAlloc(nil, bitmap_memory_size, win.MEM_COMMIT, win.PAGE_READWRITE)
}

render_weird_gradient :: proc(blue_offset, green_offset: i32) {
	pixel := ([^]u32)(bitmap_memory)

	for y in 0 ..< bitmap_height {
		for x in 0 ..< bitmap_width {
			blue := u8(x + blue_offset)
			green := u8(y + green_offset)

			pixel[y * bitmap_width + x] = (u32(green) << 8) | u32(blue)
		}
	}
}

win32_update_window :: proc(
	device_context: win.HDC,
	window_rect: win.RECT,
	x, y, width, height: i32,
) {
	window_width := window_rect.right - window_rect.left
	window_height := window_rect.bottom - window_rect.top

	win.StretchDIBits(
		device_context,
		0,
		0,
		window_width,
		window_height,
		x,
		y,
		bitmap_width,
		bitmap_height,
		bitmap_memory,
		&bitmap_info,
		win.DIB_RGB_COLORS,
		win.SRCCOPY,
	)
}
