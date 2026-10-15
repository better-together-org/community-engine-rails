# frozen_string_literal: true

module RgeoHelpers
  def rgeo_factory
    RGeo::Geographic.spherical_factory(srid: 4326)
  end

  # A simple square boundary polygon centered on the given coordinates, for exercising
  # PostGIS containment (ST_Contains) in specs without hitting a real geocoding boundary
  # provider.
  def square_boundary(center_lng:, center_lat:, radius_degrees: 0.1)
    factory = rgeo_factory
    corners = [[-1, -1], [1, -1], [1, 1], [-1, 1], [-1, -1]]
    points = corners.map { |dx, dy| factory.point(center_lng + (dx * radius_degrees), center_lat + (dy * radius_degrees)) }

    factory.multi_polygon([factory.polygon(factory.linear_ring(points))])
  end
end

RSpec.configure { |c| c.include RgeoHelpers }
