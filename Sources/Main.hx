package;

import kha.System;

/**
 * ...
 * @author Krtolica Vujadin
 * http://kodegarden.org/#bc7a0ebc2d6b13f7809b03c898116775a394dbd3
 */
class Main {
	public static function main() {
		System.init({title: "KhaNES", width: 800, height: 600}, function() {
			new KhaNES();
		});
	}
}
