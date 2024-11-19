# Load necessary libraries
library(tidyverse)
library(ggplot2)
library(ggthemes)
library(ggrepel)

# Read the CSV and convert to tibble
df <- read_csv("Storm Version CBAs - Sheet.csv") %>%
  as_tibble()

# Subset rows 1-5 since other cells are no longer useful/functional
df <- df %>%
  slice(1:5)

# Plot a line graph using ggplot2
theme_set(theme_fivethirtyeight())

ggplot(df, aes(x = `Max Intensity (m/s)`, y = `Benefit ($)`/1000000000000, label = `RCP Scenario`)) +
  geom_line(color = "black") +
  geom_point(color = "red") +
  geom_label_repel(color = 'black', arrow = NULL) +
  labs(title = "Benefit vs Max Intensity",
       subtitle = "Small climate forces generate large economic forces in return",
       x = "Max Intensity (m/s)",
       caption = "By Oliver Cochrane | Data from CLIMADA & NOAA") +
  scale_y_continuous(name = 'Benefit (in Trillions, USD)', labels = scales::dollar_format()) +
  theme(
    axis.title.x = element_text(size = 12, face = 'bold'),
    axis.title.y = element_text(size = 12, face = 'bold'))

ggsave('Benefit_MaxIntensity.png', device = 'png', width = 14, height = 10, units = 'in', dpi = 'retina')
