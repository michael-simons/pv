import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

class initial_data {

	public static void main(String... a) {
		var start = LocalDateTime.of(2023, 4, 20, 0, 0);
		var end = LocalDate.now().plusDays(1).atStartOfDay();
		DateTimeFormatter df = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
		System.out.println("ts");
		while (start.isBefore(end)) {
			System.out.println(df.format(start));
			start = start.plusMinutes(15);
		}
	}
}
