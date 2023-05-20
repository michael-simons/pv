import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

class initial_data {

	public static void main(String... a) {
		LocalDateTime x = LocalDateTime.of(2023, 4, 20, 0, 0);
		DateTimeFormatter df = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
		System.out.println("ts;power");
		while (x.isBefore(LocalDateTime.now())) {
			System.out.println(df.format(x) + ";0.0");
			x = x.plusMinutes(15);
		}
	}
}
