# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_11_09_220240) do

  create_table "actors", force: :cascade do |t|
    t.string "word"
  end

  create_table "actresses", force: :cascade do |t|
    t.string "word"
  end

  create_table "analogous_colors", force: :cascade do |t|
    t.string "word"
  end

  create_table "auditories", force: :cascade do |t|
    t.string "word"
  end

  create_table "blacklists", force: :cascade do |t|
    t.string "word"
  end

  create_table "boxers", force: :cascade do |t|
    t.string "word"
  end

  create_table "bummings", force: :cascade do |t|
    t.string "word"
  end

  create_table "cars", force: :cascade do |t|
    t.string "word"
  end

  create_table "colors", force: :cascade do |t|
    t.string "word"
  end

  create_table "complimentary_colors", force: :cascade do |t|
    t.string "word"
  end

  create_table "countries", force: :cascade do |t|
    t.string "word"
  end

  create_table "crimes", force: :cascade do |t|
    t.string "word"
  end

  create_table "directors", force: :cascade do |t|
    t.string "word"
  end

  create_table "drugs", force: :cascade do |t|
    t.string "word"
  end

  create_table "families", force: :cascade do |t|
    t.string "word"
  end

  create_table "fast_foods", force: :cascade do |t|
    t.string "word"
  end

  create_table "football_players", force: :cascade do |t|
    t.string "word"
  end

  create_table "footballs", force: :cascade do |t|
    t.string "word"
  end

  create_table "gustatories", force: :cascade do |t|
    t.string "word"
  end

  create_table "illnesses", force: :cascade do |t|
    t.string "word"
  end

  create_table "karates", force: :cascade do |t|
    t.string "word"
  end

  create_table "kinesthetics", force: :cascade do |t|
    t.string "word"
  end

  create_table "law_enforcment_agencies", force: :cascade do |t|
    t.string "word"
  end

  create_table "literatures", force: :cascade do |t|
    t.string "word"
  end

  create_table "mmas", force: :cascade do |t|
    t.string "word"
  end

  create_table "movie_industries", force: :cascade do |t|
    t.string "word"
  end

  create_table "negative_sentiments", force: :cascade do |t|
    t.string "word"
  end

  create_table "olfactories", force: :cascade do |t|
    t.string "word"
  end

  create_table "painters", force: :cascade do |t|
    t.string "word"
  end

  create_table "philosophies", force: :cascade do |t|
    t.string "word"
  end

  create_table "poets", force: :cascade do |t|
    t.string "word"
  end

  create_table "political_campaignes", force: :cascade do |t|
    t.string "word"
  end

  create_table "political_systems", force: :cascade do |t|
    t.string "word"
  end

  create_table "political_vocabularies", force: :cascade do |t|
    t.string "word"
  end

  create_table "posative_sentiments", force: :cascade do |t|
    t.string "word"
  end

  create_table "profanity_obscenes", force: :cascade do |t|
    t.string "word"
  end

  create_table "profanity_profanes", force: :cascade do |t|
    t.string "word"
  end

  create_table "profanity_vulgars", force: :cascade do |t|
    t.string "word"
  end

  create_table "psychologies", force: :cascade do |t|
    t.string "word"
  end

  create_table "religions", force: :cascade do |t|
    t.string "word"
  end

  create_table "singers", force: :cascade do |t|
    t.string "word"
  end

  create_table "spiritualities", force: :cascade do |t|
    t.string "word"
  end

  create_table "split_complimentary_colors", force: :cascade do |t|
    t.string "word"
  end

  create_table "tennis", force: :cascade do |t|
    t.string "word"
  end

  create_table "tertiary_colors", force: :cascade do |t|
    t.string "word"
  end

  create_table "theatres", force: :cascade do |t|
    t.string "word"
  end

  create_table "triadic_colors", force: :cascade do |t|
    t.string "word"
  end

  create_table "ufcs", force: :cascade do |t|
    t.string "word"
  end

  create_table "users", force: :cascade do |t|
    t.string "uploader"
    t.string "channel_id"
    t.integer "video_count"
    t.integer "accumulated_duration"
    t.json "accumulator"
    t.datetime "accumulator_last_update"
  end

  create_table "video_games", force: :cascade do |t|
    t.string "word"
  end

  create_table "visuals", force: :cascade do |t|
    t.string "word"
  end

  create_table "youtube_results", force: :cascade do |t|
    t.string "title"
    t.integer "duration"
    t.json "meta_data"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_youtube_results_on_user_id"
  end

  add_foreign_key "youtube_results", "users"
end
