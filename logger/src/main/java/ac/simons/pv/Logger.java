/*
 * Copyright 2023 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package ac.simons.pv;

import java.io.UncheckedIOException;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.Locale;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import com.ghgande.j2mod.modbus.ModbusException;
import com.ghgande.j2mod.modbus.facade.ModbusTCPMaster;
import io.github.resilience4j.core.IntervalFunction;
import io.github.resilience4j.retry.Retry;
import io.github.resilience4j.retry.RetryConfig;
import nl.basjes.energy.sunspec.MissingMandatoryFieldException;
import nl.basjes.energy.sunspec.SunSpecFetcher;
import nl.basjes.energy.sunspec.SunSpecModbusDataReader;
import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.IExecutionExceptionHandler;
import picocli.CommandLine.Model.CommandSpec;
import picocli.CommandLine.Option;
import picocli.CommandLine.Spec;

/**
 * Extracts various data from SunSpec enabled devices.
 *
 * @author Michael J. Simons
 * @since 1-ea
 */
@Command(
	name = "log-power-output",
	description = "Connects to a SunSpec device and outputs watts from module 103",
	sortOptions = false,
	versionProvider = ManifestVersionProvider.class
)
public final class Logger implements Runnable {

	@Option(names = {"-a", "--address"}, description = "The address of the SunSpec device.", required = true)
	private String address = null;

	@Option(names = {"-r", "--rate"}, description = "The rate at which measurements should be taken")
	private Duration rate = Duration.of(1, ChronoUnit.MINUTES);

	@Spec
	private CommandSpec commandSpec;

	/**
	 * Just print the error message, not the whole stack
	 */
	static class PrintExceptionMessageHandler implements IExecutionExceptionHandler {
		public int handleExecutionException(Exception ex, CommandLine cmd, CommandLine.ParseResult parseResult) {
			cmd.getErr().println(cmd.getColorScheme().errorText(ex.getMessage()));
			return cmd.getExitCodeExceptionMapper() != null
				? cmd.getExitCodeExceptionMapper().getExitCode(ex)
				: cmd.getCommandSpec().exitCodeOnExecutionException();
		}
	}

	/**
	 * Starts of PicoCLI and runs the application
	 *
	 * @param args all the arguments!
	 */
	public static void main(String... args) {

		var commandLine = new CommandLine(new Logger())
			.setCaseInsensitiveEnumValuesAllowed(true)
			.setExecutionExceptionHandler(new PrintExceptionMessageHandler());
		commandLine.execute(args);
	}

	@Override
	public void run() {

		var executor = Executors.newSingleThreadScheduledExecutor();
		var dataReader = getDataReader();
		var fetcher = new SunSpecFetcher(dataReader).useModel(103);
		var rateInSeconds = rate.toSeconds();

		executor.scheduleAtFixedRate(() -> {
			try {
				fetcher.refresh();
				System.out.printf(Locale.ENGLISH, "%s;%f%n", LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME), fetcher.model_103.getWatts());
			} catch (MissingMandatoryFieldException e) {
				throw new UncheckedIOException(e);
			} catch (ModbusException e) {
				System.err.println("Could not fetch data " + e.getMessage());
			}
		}, 0, rateInSeconds, TimeUnit.SECONDS);

		Runtime.getRuntime().addShutdownHook(new Thread(() -> {
			executor.shutdown();
			try {
				if (executor.awaitTermination(rateInSeconds * 2, TimeUnit.SECONDS)) {
					dataReader.close();
				}
			} catch (InterruptedException ignored) {
			}
		}));
	}

	private SunSpecModbusDataReader getDataReader() {
		var retryConfig = RetryConfig.custom()
			.intervalFunction(IntervalFunction.ofExponentialBackoff())
			.maxAttempts(5)
			.build();

		return Retry.decorateCheckedSupplier(Retry.of("getDataReader", retryConfig), () -> new SunSpecModbusDataReader(new ModbusTCPMaster(this.address)))
			.unchecked()
			.get();
	}
}
